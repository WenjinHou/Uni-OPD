#!/bin/bash
# shellcheck disable=SC1090,SC1091,SC2015,SC2034,SC2153

PROJECT_NAME="Qwen3_Stu_1_7B_Tea_A3B_Ins_Math_Code_Uni_OPD"
EXPERIMENT_NAME="" # 空则自动生成
TEACHER_MODEL_NAME="Qwen3-30B-A3B-Instruct-2507"
STUDENT_MODEL_NAME="Qwen3-1.7B"
ROLLOUT_BATCH_SIZE="64"
SAMPLE_N="16"
GLOBAL_BATCH_SIZE="" # 空则自动计算
LEARNING_RATE="1e-6"
LR_WARMUP_ITERS="5"
EPS_CLIP=0.2
EPS_CLIP_HIGH=0.28
OPD_CLIP_RANGE=10.0
TP_SIZE="2"

# GPU 和分布式设置
ACTOR_NUM_NODES=2
ACTOR_NUM_GPUS_PER_NODE=8
ROLLOUT_NUM_GPUS=8
HOST_NUM="${ACTOR_NUM_NODES}"
HOST_INDEX="1"
RM_URL=""
SAVE_INTERVAL="5"

# Online Filter 相关
ENABLE_FILTER="true"
FILTER_MODE="sample"
FILTER_RATIO="1"

# Advantage Shift 相关
ENABLE_ADV_SHIFT="true"
ADV_SHIFT_SCOPE="group"
ADV_SHIFT_MODE="mean"
ADV_SHIFT_DIRECTION="both"
ADV_SHIFT_DELTA="0.4"

# 训练数据配置
TRAIN_DATA_FILE="exps/scripts/OPD/strong_to_weak/configs/Qwen3_Stu_1_7B_Tea_A3B_Ins_Math_Code_Uni_OPD.yaml"
INPUT_KEY="prompt"
GROUND_TRUTH_KEY="label"

# DEBUG 参数，用于调试
DEBUG_MODE="false"

# 路径配置
CONDA_PATH="<YOUR PATH TO CONDA>"
CONDA_ENV_NAME="Uni-OPD"
MILES_PATH="<YOUR PATH TO UNI OPD>/miles"
MEGATRON_PATHS=(
    "<YOUR PATH TO UNI OPD>/Megatron-LM"
)
TEXT_MODEL_BASES=(
    "<YOUR PATH TO Qwen3 HF CKPT>"
)
DIST_MODEL_BASES=(
    "<YOUR PATH TO Qwen3 DIST CKPT>"
)

# Reward 计算
OPD_REWARD_FUNC="Uni_OPD_utils.OPD_reward.get_reward.get_reward"
OPD_REWARD_POST_PROCESS="Uni_OPD_utils.OPD_reward.post_process_rewards.post_process_rewards"
OPEN_MM_REWARD_FUNC="Uni_OPD_utils.outcome_reward.OpenMMReasoner.get_reward.get_reward"
FILTER_FUNC="exps.OPD.utils.filter.rollout_sample_filter.filter_function"

# 解析外部传入参数
while [[ $# -gt 0 ]]; do
    case "$1" in
    --project-name)
        PROJECT_NAME="$2"
        shift 2
        ;;
    --experiment-name)
        EXPERIMENT_NAME="$2"
        shift 2
        ;;
    --teacher-model-name)
        TEACHER_MODEL_NAME="$2"
        shift 2
        ;;
    --student-model-name)
        STUDENT_MODEL_NAME="$2"
        shift 2
        ;;
    --rollout-batch-size)
        ROLLOUT_BATCH_SIZE="$2"
        shift 2
        ;;
    --sample-n)
        SAMPLE_N="$2"
        shift 2
        ;;
    --global-batch-size)
        GLOBAL_BATCH_SIZE="$2"
        shift 2
        ;;
    --lr)
        LEARNING_RATE="$2"
        shift 2
        ;;
    --lr-warmup-iters)
        LR_WARMUP_ITERS="$2"
        shift 2
        ;;
    --eps-clip)
        EPS_CLIP="$2"
        shift 2
        ;;
    --eps-clip-high)
        EPS_CLIP_HIGH="$2"
        shift 2
        ;;
    --opd-clip-range)
        OPD_CLIP_RANGE="$2"
        shift 2
        ;;
    --actor-num-nodes)
        ACTOR_NUM_NODES="$2"
        shift 2
        ;;
    --actor-num-gpus-per-node)
        ACTOR_NUM_GPUS_PER_NODE="$2"
        shift 2
        ;;
    --rollout-num-gpus)
        ROLLOUT_NUM_GPUS="$2"
        shift 2
        ;;
    --tp-size)
        TP_SIZE="$2"
        shift 2
        ;;
    --host-num)
        HOST_NUM="$2"
        shift 2
        ;;
    --host-index)
        HOST_INDEX="$2"
        shift 2
        ;;
    --rm-url)
        RM_URL="$2"
        shift 2
        ;;
    --train-data-file)
        TRAIN_DATA_FILE="$2"
        shift 2
        ;;
    *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done

# GLOBAL_BATCH_SIZE 自动计算
if [ -z "${GLOBAL_BATCH_SIZE}" ]; then
    GLOBAL_BATCH_SIZE=$((ROLLOUT_BATCH_SIZE * SAMPLE_N))
fi

# EXPERIMENT_NAME 自动生成
if [ -z "${EXPERIMENT_NAME}" ]; then
    EXPERIMENT_NAME="${STUDENT_MODEL_NAME}_OPD_T${TEACHER_MODEL_NAME}_rbs${ROLLOUT_BATCH_SIZE}_sn${SAMPLE_N}_gbs${GLOBAL_BATCH_SIZE}_lr${LEARNING_RATE}"
fi

# 构造候选目录列表
TEACHER_DIRS=()
STUDENT_DIRS=()
STUDENT_DIST_DIRS=()
for base in "${TEXT_MODEL_BASES[@]}"; do
    TEACHER_DIRS+=("${base}/${TEACHER_MODEL_NAME}")
    STUDENT_DIRS+=("${base}/${STUDENT_MODEL_NAME}")
done
for base in "${DIST_MODEL_BASES[@]}"; do
    STUDENT_DIST_DIRS+=("${base}/${STUDENT_MODEL_NAME}")
done

# student model args 路径（按命名规则推导）
STUDENT_MODEL_ARGS_FILE=$(echo "${STUDENT_MODEL_NAME}" |
    sed 's/-Instruct//g; s/-Thinking//g; s/Qwen3-VL-/qwen3-/g; s/Qwen3-/qwen3-/g; s/-2B/-1.7B/g')
STUDENT_MODEL_ARGS_PATH="scripts/models/${STUDENT_MODEL_ARGS_FILE}.sh"

#! OPD 不支持 EVAL
EVAL_DATA_FILE=""

LAUNCHER_SCRIPT="${MILES_PATH}/Uni_OPD_utils/ray_launcher.py"
STOP_RAY_SCRIPT="${MILES_PATH}/Uni_OPD_utils/scripts/ray/stop_ray.sh"
STOP_SGLANG_SCRIPT="${MILES_PATH}/Uni_OPD_utils/scripts/server/stop_server.sh"
START_RAY_SCRIPT="${MILES_PATH}/Uni_OPD_utils/scripts/ray/start_ray.sh"
NETWORK_ENV_SCRIPT="${MILES_PATH}/Uni_OPD_utils/scripts/ray/network_envs.sh"

set -ex

# 输出目录
export OUTPUT_DIR="${MILES_PATH}/outputs"
export TENSORBOARD_DIR="${OUTPUT_DIR}/logs/tensorboard/${PROJECT_NAME}/${EXPERIMENT_NAME}"
export EXPERIMENT_DIR="${OUTPUT_DIR}/${PROJECT_NAME}/${EXPERIMENT_NAME}"
export CKPT_DIR="${EXPERIMENT_DIR}/ckpt"
export LOG_DIR="${EXPERIMENT_DIR}/logs"
export DEBUG_DIR="${EXPERIMENT_DIR}/debug"

# 设置训练默认代理
readonly MAIN_PROXY="http://star-proxy.oa.com:3128"
readonly NO_PROXY=""
readonly DEFAULT_PROXY="${NO_PROXY}"
export http_proxy="${DEFAULT_PROXY}" https_proxy="${DEFAULT_PROXY}"

mkdir -p "${TENSORBOARD_DIR}" "${CKPT_DIR}" "${LOG_DIR}"
CUR_TIME=$(date +%Y%m%d_%H%M%S)

# DEBUG 专用参数，默认关闭
if [ "${DEBUG_MODE}" = "true" ]; then
    export NCCL_DEBUG="WARN" # "INFO"
    DEBUG_ARGS=(
        # save_debug_rollout_data.format(rollout_id)
        --save-debug-rollout-data "${DEBUG_DIR}/rollout_data/${CUR_TIME}/step_{rollout_id}.pt"
    )
    SGLANG_CUDA_GRAPH=(--sglang-disable-cuda-graph)
else
    export NCCL_DEBUG="WARN"
    DEBUG_ARGS=()
    SGLANG_CUDA_GRAPH=()
fi

# resolve_dir：从候选目录中找第一个存在的
resolve_dir() {
    for d in "$@"; do
        [ -d "$d" ] && {
            echo "$d"
            return
        }
    done
    echo "Error: No valid directory found among: $*" >&2
    exit 1
}

MEGATRON_PATH="$(resolve_dir "${MEGATRON_PATHS[@]}")"
# TEACHER_DIR=$(resolve_dir "${TEACHER_DIRS[@]}")
STUDENT_DIR=$(resolve_dir "${STUDENT_DIRS[@]}")
STUDENT_DIST_DIR=$(resolve_dir "${STUDENT_DIST_DIRS[@]}")

CKPT_ARGS=(
    --hf-checkpoint "${STUDENT_DIR}" # 用于初始化 SGLang 并提供分词器的 HuggingFace 检查点的路径
    --ref-load "${STUDENT_DIST_DIR}" # 参考模型检查点的路径
    --load "${CKPT_DIR}"             # 要加载的训练模型检查点的路径
    --save "${CKPT_DIR}"             # 保存检查点的路径
    --save-interval "${SAVE_INTERVAL}"
    # --save-hf "${CKPT_DIR}/hf/step_{rollout_id}" # 保存 HuggingFace 格式检查点的路径模板，{rollout_id} 会被替换为实际的 rollout ID
    # --async-save # 启用异步检查点保存，不要开！和保存 mcore 同时保存 hf 冲突
)

ROLLOUT_ARGS=(
    --prompt-data "${TRAIN_DATA_FILE}"
    --input-key "${INPUT_KEY}"
    --label-key "${GROUND_TRUTH_KEY}"
    --apply-chat-template
    # By default it is thinking mode
    --apply-chat-template-kwargs '{"enable_thinking": false}'
    --rollout-shuffle
    --num-epoch 10
    --rollout-batch-size "${ROLLOUT_BATCH_SIZE}"
    --n-samples-per-prompt "${SAMPLE_N}"
    --rollout-max-prompt-len 4096
    --rollout-max-response-len 16384
    --rollout-temperature 1
    --global-batch-size "${GLOBAL_BATCH_SIZE}"
    --balance-data # 使用 Karmarkar-Karp 方法重新划分每个 rollout 批次，使每个数据并行 rank 获得相似的总 token 数，有利于提高训练速度
)

if [ "${ENABLE_FILTER,,}" = true ]; then
    echo "Enable filter"
    FILTER_ARGS=(
        --balance-rollout-by-outcome-reward
        --rollout-sample-filter-path "${FILTER_FUNC}"
        --balance-rollout-scope "${FILTER_MODE}"
        --balance-rollout-ratio "${FILTER_RATIO}"
    )
else
    echo "Disable filter"
    FILTER_ARGS=()
fi

# 互斥检查：advantage shift 和 greedy advantage mask 不能同时启用
if [ "${ENABLE_ADV_SHIFT,,}" = true ] && [ "${ENABLE_ADV_MASK,,}" = true ]; then
    echo "Error: ENABLE_ADV_SHIFT and ENABLE_ADV_MASK cannot be enabled at the same time."
    exit 1
fi

if [ "${ENABLE_ADV_SHIFT,,}" = true ]; then
    echo "Enable adv shift"
    ADV_SHIFT_ARGS=(
        --use-opd-margin-shift
        --opd-margin-scope "${ADV_SHIFT_SCOPE}"         # global 或 group
        --opd-margin-mode "${ADV_SHIFT_MODE}"           # minmax 或 mean
        --opd-margin-delta "${ADV_SHIFT_DELTA}"         # 0.1
        --opd-margin-direction "${ADV_SHIFT_DIRECTION}" # correct_up, incorrect_down, both
    )
else
    ADV_SHIFT_ARGS=()
    echo "Disable adv shift"
fi

if [ "${ENABLE_ADV_MASK,,}" = true ]; then
    echo "Enable greedy advantage mask"
    ADV_MASK_ARGS=(
        --use-opd-margin-mask-greedy
        --opd-margin-scope "${ADV_SHIFT_SCOPE}"                    # global 或 group
        --opd-margin-mode "${ADV_SHIFT_MODE}"                      # minmax 或 mean
        --opd-margin-delta "${ADV_SHIFT_DELTA}"                    # 0.1
        --opd-mask-min-retain-ratio "${ADV_MASK_MIN_RETAIN_RATIO}" # 0.25
    )
else
    ADV_MASK_ARGS=()
    echo "Disable greedy advantage mask"
fi

#! OPD 不支持 EVAL
EVAL_ARGS=(
    # --eval-interval 20
    # --eval-prompt-data aime "${EVAL_DATA_FILE}"
    # --n-samples-per-eval-prompt 4
    # --eval-max-response-len 16384
    # --eval-top-p 1
)

PERF_ARGS=(
    --tensor-model-parallel-size "${TP_SIZE}"
    --sequence-parallel
    --pipeline-model-parallel-size 1
    --context-parallel-size 1
    --expert-model-parallel-size 1
    --expert-tensor-parallel-size 1
    --recompute-granularity full
    --recompute-method uniform
    --recompute-num-layers 1

    # --micro-batch-size 1
    --use-dynamic-batch-size
    --max-tokens-per-gpu 16384
)

GRPO_ARGS=(
    --advantage-estimator on_policy_distillation
    # --use-kl-loss
    --kl-loss-coef 0.00
    --kl-loss-type low_var_kl
    --entropy-coef 0.00
    --eps-clip "${EPS_CLIP}"
    --eps-clip-high "${EPS_CLIP_HIGH}"
    --use-teacher-student-logprob-clip
    --teacher-student-logprob-clip-range "${OPD_CLIP_RANGE}"
)

OPTIMIZER_ARGS=(
    --optimizer adam
    --lr "${LEARNING_RATE}"
    --lr-decay-style constant
    --lr-warmup-iters "${LR_WARMUP_ITERS}"
    --weight-decay 0.1 # Weight decay for the optimizer
    --adam-beta1 0.9
    --adam-beta2 0.98
)

WANDB_ARGS=(
    #--use-wandb
    # --wandb-project miles-dev
    # --wandb-group Qwen3_OPD
    # --wandb-key ${WANDB_KEY}
)

TENSORBOARD_ARGS=(
    --use-tensorboard
    --tensorboard-dir "${TENSORBOARD_DIR}"
)

SGLANG_ARGS=(
    --rollout-num-gpus-per-engine 1
    --sglang-mem-fraction-static 0.75
    "${SGLANG_CUDA_GRAPH[@]}"
)

MISC_ARGS=(
    --attention-dropout 0.0
    --hidden-dropout 0.0
    --accumulate-allreduce-grads-in-fp32
    --attention-softmax-in-fp32
    --attention-backend flash
    --colocate # 让训练和推理共用同一组 GPU，而不是分开部署到不同 GPU 上
)

MODEL_ARGS_FILE="${MILES_PATH}/${STUDENT_MODEL_ARGS_PATH}"
[ -f "${MODEL_ARGS_FILE}" ] && source "${MODEL_ARGS_FILE}" || {
    echo "Error: ${MODEL_ARGS_FILE} not found"
    exit 1
}

# Conda 激活
if [ -d "${CONDA_PATH}" ]; then
    source "${CONDA_PATH}/bin/activate"
else
    echo "Error: Failed to source conda at ${CONDA_PATH}/bin/activate"
    exit 1
fi

conda activate "${CONDA_ENV_NAME}" || {
    echo "Error: Conda env '$CONDA_ENV_NAME' not found"
    exit 1
}

# Teacher server
SERVER_LOG_FILE="${LOG_DIR}/sglang_teacher_${CUR_TIME}.log"
SERVER_GPU_UTILS="0.8"

is_server_alive() { curl -sf "${SERVER_URL}/health_generate" >/dev/null 2>&1; }

start_server() {
    if [ -d "${TEACHER_DIR}" ]; then
        echo "Starting teacher model server: ${TEACHER_MODEL_NAME}..."
        nohup env CUDA_VISIBLE_DEVICES=7 \
            http_proxy="" https_proxy="" HTTP_PROXY="" HTTPS_PROXY="" \
            python -m sglang.launch_server \
            --model-path "${TEACHER_DIR}" \
            --host 0.0.0.0 \
            --port "${TEACHER_PORT}" \
            --tp 1 \
            --chunked-prefill-size 4096 \
            --mem-fraction-static "${SERVER_GPU_UTILS}" \
            >"${SERVER_LOG_FILE}" 2>&1 &
        disown
    else
        echo "Error: Teacher model directory not found: ${TEACHER_DIR}"
        exit 1
    fi
}

wait_server() {
    echo "Waiting for server..."
    for i in {1..1000}; do
        if is_server_alive; then
            echo "Server ready."
            return 0
        fi
        echo "Not ready yet ($i/1000)..."
        tail -n 5 "${SERVER_LOG_FILE}"
        sleep 10
    done
    echo "Server failed to start"
    exit 1
}

# 启动/停止 Ray
if [ -n "${HOST_NUM}" ] && [ -n "${HOST_INDEX}" ]; then
    bash "${STOP_RAY_SCRIPT}" "${HOST_NUM}" "${HOST_INDEX}"
    bash "${STOP_SGLANG_SCRIPT}" "${HOST_NUM}" "${HOST_INDEX}"
    bash "${START_RAY_SCRIPT}" "${HOST_NUM}" "${HOST_INDEX}"
else
    bash "${STOP_RAY_SCRIPT}"
    bash "${STOP_SGLANG_SCRIPT}"
    bash "${START_RAY_SCRIPT}"
fi

NVLINK_COUNT=$(nvidia-smi topo -m 2>/dev/null | grep -o 'NV[0-9][0-9]*' | wc -l)
HAS_NVLINK=$([ "$NVLINK_COUNT" -gt 0 ] && echo 1 || echo 0)
echo "HAS_NVLINK: $HAS_NVLINK"

# 设置环境变量
source "${NETWORK_ENV_SCRIPT}"
export PYTHONPATH="${PYTHONPATH}:${MEGATRON_PATH}"
export CUDA_DEVICE_MAX_CONNECTIONS=1
export NCCL_NVLS_ENABLE="${HAS_NVLINK}"
export DEPRECATED_MEGATRON_COMPATIBLE="1" # 兼容旧版 Megatron，使用 Uni-OPD conda 环境的时候必须设置
export PYTHONBUFFERED=16

cd "${MILES_PATH}" || exit

echo "================================================================"
echo "  EXPERIMENT              : ${EXPERIMENT_NAME}"
echo "  STUDENT                 : ${STUDENT_MODEL_NAME} -> ${STUDENT_DIR}"
echo "  TEACHER                 : ${TEACHER_MODEL_NAME} -> ${TEACHER_DIR}"
echo "  ROLLOUT_BATCH_SIZE      : ${ROLLOUT_BATCH_SIZE}"
echo "  SAMPLE_N                : ${SAMPLE_N}"
echo "  GLOBAL_BATCH_SIZE       : ${GLOBAL_BATCH_SIZE}"
echo "  LEARNING_RATE           : ${LEARNING_RATE}"
echo "  ACTOR_NUM_NODES         : ${ACTOR_NUM_NODES}"
echo "  ACTOR_NUM_GPUS_PER_NODE : ${ACTOR_NUM_GPUS_PER_NODE}"
echo "  ROLLOUT_NUM_GPUS        : ${ROLLOUT_NUM_GPUS}"
echo "================================================================"

TRAIN_LOG_FILE="${LOG_DIR}/train_${CUR_TIME}.log"
python "${LAUNCHER_SCRIPT}" train.py \
    --actor-num-nodes "${ACTOR_NUM_NODES}" \
    --actor-num-gpus-per-node "${ACTOR_NUM_GPUS_PER_NODE}" \
    --rollout-num-gpus "${ROLLOUT_NUM_GPUS}" \
    "${TENSORBOARD_ARGS[@]}" \
    "${OPTIMIZER_ARGS[@]}" \
    "${ADV_SHIFT_ARGS[@]}" \
    "${ADV_MASK_ARGS[@]}" \
    "${ROLLOUT_ARGS[@]}" \
    "${SGLANG_ARGS[@]}" \
    "${FILTER_ARGS[@]}" \
    "${WANDB_ARGS[@]}" \
    "${DEBUG_ARGS[@]}" \
    "${MODEL_ARGS[@]}" \
    "${PERF_ARGS[@]}" \
    "${EVAL_ARGS[@]}" \
    "${GRPO_ARGS[@]}" \
    "${MISC_ARGS[@]}" \
    "${CKPT_ARGS[@]}" \
    "${RM_ARGS[@]}" \
    2>&1 | tee "${TRAIN_LOG_FILE}"
