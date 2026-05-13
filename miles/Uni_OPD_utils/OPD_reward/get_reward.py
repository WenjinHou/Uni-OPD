import asyncio
import logging
import os
import random
import time
from argparse import Namespace

import aiohttp

from exps.OPD.utils.reward.reward_manager import RMSystemManager
from exps.OPD.utils.reward.rule_base_reward import get_rule_based_reward  # noqa
from exps.OPD.utils.reward.session_manager import RewardSessionManager
from miles.utils.types import Sample

logger = logging.getLogger(__name__)

_MAX_RETRIES = 5
_RETRY_DELAY = 2.0  # 每次重试间隔（秒）


# 失败样本的哨兵标记键
REWARD_FAILED_KEY = "__opd_reward_failed__"

# 设置代理
os.environ["http_proxy"], os.environ["https_proxy"] = "", ""


# 设置在 --custom-rm-path 当中
# 用于 miles/rollout/rm_hub/__init__.py 的 async_rm 方法
async def get_reward(args: Namespace, sample: Sample, **kwargs) -> dict[str]:
    start_time = time.time()

    rm_manager = RMSystemManager(args)
    session_manager = RewardSessionManager()
    # 结果正确性验证（async：code 分支会通过 asyncio.to_thread 发起远程评测，不阻塞事件循环）
    response_correct, rule_based_metadata = await get_rule_based_reward(args, sample)
    # response_correct, rule_based_metadata = None, {}

    payload = rm_manager.build_payload(sample)

    last_exception = None
    for attempt in range(1, _MAX_RETRIES + 1):
        url = rm_manager.get_next_url(sample)

        try:
            async with session_manager.inflight_sem:
                session = await session_manager.get_session()
                async with session.post(url, json=payload) as resp:
                    resp.raise_for_status()
                    res = await resp.json()
                    # input_token_logprobs 是 teacher 对整个输入序列（prompt + response）的每个 token 的 logps
                    # res 结构示例：
                    # {
                    #     ...
                    #     "meta_info": {
                    #         "input_token_logprobs": [
                    #             [None,  token_id_0, None],     # 第一个 token 无 logprob
                    #             [logprob, token_id_1, None],   # 第二个 token 的 logprob
                    #             [logprob,  token_id_2, None],  # 第三个 token 的 logprob
                    #             ...
                    #         ],
                    #     },
                    # }

            res["reward_time"] = time.time() - start_time
            res["teacher_url"] = url
            res["response_correct"] = response_correct
            res["rule_based_metadata"] = rule_based_metadata
            return res

        except (aiohttp.ClientError, asyncio.TimeoutError, RuntimeError) as e:
            last_exception = e
            logger.warning(
                f"Attempt {attempt}/{_MAX_RETRIES} failed for teacher={sample.teacher_model_name}, "
                f"url={url}: {type(e).__name__}: {e}"
            )
            is_bad_fd = isinstance(e, aiohttp.ClientOSError) and e.errno == 9
            is_session_closed = isinstance(e, RuntimeError) and "Session is closed" in str(e)
            is_fd_reuse = isinstance(e, RuntimeError) and "File descriptor" in str(e) and "used by transport" in str(e)
            if is_bad_fd or is_session_closed or is_fd_reuse:
                await session_manager.reset_session()
            if attempt < _MAX_RETRIES:
                await asyncio.sleep(_RETRY_DELAY * attempt + random.uniform(0, 0.2))
        except Exception as e:
            last_exception = e
            logger.warning(
                f"Unexpected error on attempt {attempt}/{_MAX_RETRIES} for url={url}: {type(e).__name__}: {e}"
            )
            if attempt < _MAX_RETRIES:
                await asyncio.sleep(_RETRY_DELAY * attempt + random.uniform(0, 0.2))

    logger.error(
        f"All {_MAX_RETRIES} attempts failed. "
        f"last error: {type(last_exception).__name__}: {last_exception}. "
        f"Marking sample as failed (will be masked in loss)."
    )

    return {
        REWARD_FAILED_KEY: True,
        "response_correct": response_correct,
        "rule_based_metadata": rule_based_metadata,
        "reward_time": time.time() - start_time,
        "meta_info": {"input_token_logprobs": []},
    }
