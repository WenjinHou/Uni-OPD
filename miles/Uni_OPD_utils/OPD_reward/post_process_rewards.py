import logging

import torch

from exps.OPD.utils.reward.get_reward import REWARD_FAILED_KEY
from miles.utils.types import Sample

logger = logging.getLogger(__name__)

# 失败样本的 teacher_log_probs 哨兵值
TEACHER_LOGP_FAILED_SENTINEL = -100.0


# 设置在 --custom-reward-post-process-path 当中
# 用于 miles/ray/rollout.py 的 _post_process_rewards 方法中，调用 custom_reward_post_process_func
def post_process_rewards(args, samples: list[Sample], **kwargs) -> tuple[list[float], list[float]]:
    """
    Post process rewards.
    若 teacher 调用失败，将该样本的 teacher_log_probs 全部填充为 TEACHER_LOGP_FAILED_SENTINEL(-100)，
    作为哨兵值在 loss.py 中识别并 mask 掉，保证训练流程不中断。

    Return:
        raw_rewards: list[float], the original rewards without any post processing, used for logging and metric checking
        rewards: list[float], the rewards after post processing, used for training
    """
    rewards: list[dict[str]] = [sample.reward for sample in samples]

    num_failed = 0
    teacher_log_probs_list: list[torch.Tensor] = []

    for i, (reward, sample) in enumerate(zip(rewards, samples, strict=False)):
        response_length: int = sample.response_length

        response_correct: bool = reward.get("response_correct", None)
        # 失败样本处理
        if reward.get(REWARD_FAILED_KEY, False):
            num_failed += 1
            # logger.warning(
            #     f"[post_process_rewards] sample[{i}] reward failed, "
            #     f"filling teacher_log_probs with sentinel {TEACHER_LOGP_FAILED_SENTINEL} "
            #     f"(response_length={response_length}). Will be masked in pg_loss."
            # )
            # 用哨兵值填充，shape 与 student 一致，不影响后续 cat
            t_log_probs = torch.full((response_length,), TEACHER_LOGP_FAILED_SENTINEL, dtype=torch.float32)
            sample.teacher_log_probs = t_log_probs
            sample.response_correct = response_correct
            teacher_log_probs_list.append(t_log_probs)
            continue

        # 正常样本处理
        try:
            t_log_probs = torch.tensor(
                [item[0] for item in reward["meta_info"]["input_token_logprobs"][1:]],
                dtype=torch.float32,
            )
            # teacher_log_probs 变成仅 response 部分，长度 = response_length
            t_log_probs = t_log_probs[-response_length:]
        except Exception as e:
            # 解析失败也用哨兵值填充
            num_failed += 1
            logger.warning(
                f"[post_process_rewards] sample[{i}] logprob parse error: {e}, "
                f"filling with sentinel {TEACHER_LOGP_FAILED_SENTINEL}."
            )
            t_log_probs = torch.full((response_length,), TEACHER_LOGP_FAILED_SENTINEL, dtype=torch.float32)

        sample.response_correct = response_correct
        sample.teacher_log_probs = t_log_probs
        teacher_log_probs_list.append(t_log_probs)

    if num_failed > 0:
        logger.warning(
            f"[post_process_rewards] {num_failed}/{len(samples)} samples failed, "
            f"their pg_loss will be zeroed by sentinel mask in loss.py."
        )

    return teacher_log_probs_list, teacher_log_probs_list
