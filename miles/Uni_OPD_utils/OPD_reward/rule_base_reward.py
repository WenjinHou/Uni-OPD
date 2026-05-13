import asyncio
import logging
from argparse import Namespace

# from exps.RL.utils.reward.PRIME_code import compute_score as compute_score_code
from exps.RL.utils.reward.PRIME_code_server.server import CodeJudgeClient, CodeJudgeResponse

# from miles.rollout.rm_hub.math_utils import grade_answer_verl as compute_score_math
from Math.generate.verify_deepmath.reward_func import reward_func as compute_score_math
from miles.utils.types import Sample

logger = logging.getLogger(__name__)

# 这里获取全局唯一实例，避免重复创建连接和服务器列表
_code_judge_client: CodeJudgeClient = CodeJudgeClient()


def _compute_score_code(completion: str, test_cases) -> tuple[float | bool, list | dict | None]:
    """通过远程 CodeJudgeClient 服务评测代码正确性，接口兼容原 compute_score。
    注意：此函数内部使用 requests.post（同步阻塞），必须通过 asyncio.to_thread 调用。
    """
    resp: CodeJudgeResponse = _code_judge_client.judge(completion, test_cases)
    if resp.error:
        logger.warning(f"[CodeJudge] judge returned error: {resp.error}")
    return resp.success, resp.metadata


# CodeJudgeClient.judge 内部使用 requests.post（同步阻塞）+ time.sleep，
# 必须放到线程池中执行，否则会阻塞整个 asyncio 事件循环，
# 导致 abort wait 等异步操作 hang 住。


async def get_rule_based_reward(args: Namespace, sample: Sample) -> tuple[bool, dict[str]]:
    try:
        if sample.teacher_model_name.lower() in ("vlm-puzzle", "vlm-math", "vlm-chart"):
            from exps.RL.utils.reward.OpenMMReasoner.get_reward import get_reward as get_reward_openmm

            grade_result: dict = await get_reward_openmm(args, sample)
            response_correct = grade_result["acc_score"] == 1.0
            grade_result = (response_correct, grade_result)
        elif sample.teacher_model_name.lower() in ("code", "code-a3b"):
            grade_result = await asyncio.to_thread(_compute_score_code, sample.response, sample.label)
        else:  # Default math 格式的数学验证（纯 CPU 计算，毫秒级，不需要线程池）
            grade_result = compute_score_math(sample.response, sample.label)

        if isinstance(grade_result, tuple):
            response_correct, metadata = grade_result
        elif isinstance(grade_result, bool):
            response_correct, metadata = grade_result, {}
        elif isinstance(grade_result, dict):
            response_correct, metadata = grade_result["correct"], grade_result
        else:
            response_correct, metadata = bool(grade_result), {}

    except Exception as e:
        logger.warning(f"[get_reward] grade_answer_verl raised an exception: {type(e).__name__}: {e}")
        response_correct, metadata = False, {}

    return response_correct, metadata
