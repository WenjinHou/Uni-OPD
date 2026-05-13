# Uni-OPD 训练环境构建

<b>中文</b> | <a href="/docs/build_env.md">English</a>

## 简介

本文档介绍如何从零开始搭建 **Uni-OPD 训练环境**，覆盖了完整 OPD 流程所需的全部依赖。

开始之前，请先准备好：

- 一份 **Uni-OPD** 仓库的本地克隆；
- 已安装 **Anaconda** 或 **Miniconda**。

按照下面的步骤完成后，你将得到：

```text
- <YOUR PATH TO UNI OPD>/        # 仓库根目录
  - miles/                       # RL / OPD 训练框架（即本仓库）
  - Megatron-LM/                 # 训练后端（克隆获得）
  - sglang/                      # rollout / 推理后端（克隆获得）
  ...
```

以及一个名为 **`Uni-OPD`** 的训练专用 conda 环境。

## 第 1 步：克隆训练侧依赖

我们将 `Megatron-LM` 与 `sglang` 都固定到具体的 commit，以保证可复现性。

```bash
export BASE_DIR="<YOUR PATH TO UNI OPD>"
export SGLANG_COMMIT="24c91001cf99ba642be791e099d358f4dfe955f5"
export MEGATRON_COMMIT="3714d81d418c9f1bca4594fc35f9e8289f652862"

cd "${BASE_DIR}"

# Megatron-LM（递归克隆，含子模块）
git clone https://github.com/NVIDIA/Megatron-LM.git --recursive
cd Megatron-LM && git checkout "${MEGATRON_COMMIT}" && cd ..

# SGLang（rollout / 推理后端）
git clone https://github.com/sgl-project/sglang.git
cd sglang && git checkout "${SGLANG_COMMIT}" && cd ..
```

## 第 2 步：创建 conda 环境并安装依赖

> 由于 Flash-Attention、Apex 与 TransformerEngine 都需要从源码编译，整套安装大约需要 **30 ~ 60 分钟**，请预留充足的时间和磁盘空间。

```bash
## ---- 配置区 ----
export CONDA_PATH="<YOUR PATH TO CONDA>"
export MILES_DIR="<YOUR PATH TO UNI OPD>/miles"
export MEGATRON_DIR="<YOUR PATH TO UNI OPD>/Megatron-LM"
export SGLANG_DIR="<YOUR PATH TO UNI OPD>/sglang"

## ---- 执行区 ----

# 创建并激活 conda 环境
source "${CONDA_PATH}/bin/activate"
conda create -n Uni-OPD python=3.12.12 -y
conda activate Uni-OPD
pip config set global.root-user-action ignore

# 锁定 cuda-python，避免 SGLang 引入 CUDA 13.0
pip install cuda-python==13.1.0

# PyTorch（CUDA 12.8 版本）
pip install torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 \
    --index-url https://download.pytorch.org/whl/cu128

# 以 editable 模式安装 SGLang
cd "${SGLANG_DIR}"
pip install -e "python[all]"

pip install cmake ninja math-verify

# Flash-Attention 2：编译耗时较长，优先安装
# 请按你的 GPU 架构选择对应 SM（如 NVIDIA H20 / H100 选 "9.0"）
TORCH_CUDA_ARCH_LIST="9.0" MAX_JOBS=64 \
    pip -v install "flash-attn==2.7.4.post1" --no-build-isolation

# mbridge：模型通信桥接库，固定 commit
pip install "git+https://github.com/ISEEKYAN/mbridge.git@89eb10887887bc74853f89a4de258c0702932a1c" --no-deps

# TransformerEngine
pip -v install --no-build-isolation "transformer_engine[pytorch]==2.10.0"

# flash-linear-attention：线性注意力加速库
pip install flash-linear-attention==0.4.0

# NVIDIA Apex：从源码编译，启用 C++/CUDA 扩展
NVCC_APPEND_FLAGS="--threads 4" \
    pip -v install --disable-pip-version-check --no-cache-dir --no-build-isolation \
    --config-settings "--build-option=--cpp_ext --cuda_ext --parallel 8" \
    "git+https://github.com/NVIDIA/apex.git@10417aceddd7d5d05d7cbf7b0fc2daad1105f8b4"

# torch_memory_saver：PyTorch 显存管理工具
pip install git+https://github.com/fzyzcjy/torch_memory_saver.git@d64a639 \
    --no-cache-dir --force-reinstall

# NVIDIA Resiliency Extension：容错训练相关工具
pip install git+https://github.com/NVIDIA/nvidia-resiliency-ext --no-build-isolation

# Megatron-Bridge：Megatron 与 RL 框架的桥接库（dev_rl 分支）
pip install git+https://github.com/fzyzcjy/Megatron-Bridge.git@dev_rl --no-build-isolation

# nvidia-modelopt：NVIDIA 模型优化工具（量化、剪枝等）
pip install "nvidia-modelopt[torch]>=0.37.0" --no-build-isolation

# tilelang：Tile 计算语言库（CUDA 12.8 nightly 版本）
pip install tilelang -f https://tile-ai.github.io/whl/nightly/cu128/

# Megatron-LM：从源码以 editable 模式安装，方便后续打补丁
cd "${MEGATRON_DIR}"
pip install -e .

# 安装 miles（本仓库）
cd "${MILES_DIR}"
pip install -e .

# 修复 PyTorch issue #168167：锁定一个已知兼容的 cuDNN 版本
pip install "nvidia-cudnn-cu12==9.16.0.29"

# Megatron-LM 目前仍依赖 numpy 1.x
pip install "numpy<2"
```

## 第 3 步：应用 SGLang 与 Megatron 补丁

Uni-OPD 针对固定上游 commit 提供了一组小补丁（位于 [`miles/docker/patch/v0.5.7`](../miles/docker/patch)）。在 Python 包安装完成后请执行：

```bash
# SGLang 补丁
cd "${SGLANG_DIR}"
git apply "${MILES_DIR}/docker/patch/v0.5.7/sglang_psp.patch"

# Megatron-LM 补丁
cd "${MEGATRON_DIR}"
git apply "${MILES_DIR}/docker/patch/v0.5.7/megatron.patch"
```

## 自检

完成全部安装后，可以做一次快速自检：

```bash
conda activate Uni-OPD
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.cuda.is_available())"
python -c "import flash_attn, transformer_engine, sglang; print('flash_attn / TE / sglang OK')"
python -c "import megatron, miles; print('megatron / miles OK')"
```

如果三条命令都能成功执行，说明训练环境已经就绪，可以前往 [`exps/scripts/OPD`](../exps/scripts/OPD) 启动训练任务。
