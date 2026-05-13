# Uni-OPD Training Environment Setup

<a href="/docs/build_env_zh.md">中文</a> | <b>English</b>

## Introduction

This document walks through building the **Uni-OPD training environment** from scratch, including every dependency required to launch a full OPD run.

Before you start, please prepare:

- A clone of the **Uni-OPD** repository.
- A working **Anaconda** or **Miniconda** installation.

After following the steps below, you will end up with:

```text
- <YOUR PATH TO UNI OPD>/        # repo root
  - miles/                       # RL / OPD training framework (this repo)
  - Megatron-LM/                 # training backend (cloned)
  - sglang/                      # rollout / inference backend (cloned)
  ...
```

and a dedicated conda environment named **`Uni-OPD`** for training.

## Step 1. Clone the training-side dependencies

We pin both `Megatron-LM` and `sglang` to specific commits to guarantee reproducibility.

```bash
export BASE_DIR="<YOUR PATH TO UNI OPD>"
export SGLANG_COMMIT="24c91001cf99ba642be791e099d358f4dfe955f5"
export MEGATRON_COMMIT="3714d81d418c9f1bca4594fc35f9e8289f652862"

cd "${BASE_DIR}"

# Megatron-LM (recursive clone for its submodules)
git clone https://github.com/NVIDIA/Megatron-LM.git --recursive
cd Megatron-LM && git checkout "${MEGATRON_COMMIT}" && cd ..

# SGLang (rollout / inference backend)
git clone https://github.com/sgl-project/sglang.git
cd sglang && git checkout "${SGLANG_COMMIT}" && cd ..
```

## Step 2. Create the conda environment and install dependencies

> The whole installation may take **30 ~ 60 minutes** because Flash-Attention, Apex and TransformerEngine all need to be compiled from source. Please reserve enough time and disk space.

```bash
## ---- Configuration ----
export CONDA_PATH="<YOUR PATH TO CONDA>"
export MILES_DIR="<YOUR PATH TO UNI OPD>/miles"
export MEGATRON_DIR="<YOUR PATH TO UNI OPD>/Megatron-LM"
export SGLANG_DIR="<YOUR PATH TO UNI OPD>/sglang"

## ---- Execution ----

# Create and activate the conda env
source "${CONDA_PATH}/bin/activate"
conda create -n Uni-OPD python=3.12.12 -y
conda activate Uni-OPD
pip config set global.root-user-action ignore

# Pin cuda-python to prevent SGLang from pulling in CUDA 13.0
pip install cuda-python==13.1.0

# PyTorch (CUDA 12.8 build)
pip install torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 \
    --index-url https://download.pytorch.org/whl/cu128

# Install SGLang in editable mode
cd "${SGLANG_DIR}"
pip install -e "python[all]"

pip install cmake ninja math-verify

# Flash-Attention 2: long compile time, install early.
# Use the SM arch matching your GPU (e.g. "9.0" for NVIDIA H20 / H100).
TORCH_CUDA_ARCH_LIST="9.0" MAX_JOBS=64 \
    pip -v install "flash-attn==2.7.4.post1" --no-build-isolation

# mbridge: model-communication bridge, pinned to a specific commit
pip install "git+https://github.com/ISEEKYAN/mbridge.git@89eb10887887bc74853f89a4de258c0702932a1c" --no-deps

# TransformerEngine
pip -v install --no-build-isolation "transformer_engine[pytorch]==2.10.0"

# flash-linear-attention: linear-attention acceleration kernels
pip install flash-linear-attention==0.4.0

# NVIDIA Apex: build from source with C++ / CUDA extensions enabled
NVCC_APPEND_FLAGS="--threads 4" \
    pip -v install --disable-pip-version-check --no-cache-dir --no-build-isolation \
    --config-settings "--build-option=--cpp_ext --cuda_ext --parallel 8" \
    "git+https://github.com/NVIDIA/apex.git@10417aceddd7d5d05d7cbf7b0fc2daad1105f8b4"

# torch_memory_saver: GPU memory management helper
pip install git+https://github.com/fzyzcjy/torch_memory_saver.git@d64a639 \
    --no-cache-dir --force-reinstall

# NVIDIA Resiliency Extension (fault-tolerant training utilities)
pip install git+https://github.com/NVIDIA/nvidia-resiliency-ext --no-build-isolation

# Megatron-Bridge: bridges Megatron and the RL framework (dev_rl branch)
pip install git+https://github.com/fzyzcjy/Megatron-Bridge.git@dev_rl --no-build-isolation

# nvidia-modelopt: NVIDIA model optimization toolkit (quantization, pruning, ...)
pip install "nvidia-modelopt[torch]>=0.37.0" --no-build-isolation

# tilelang: Tile-language compute library (nightly build for CUDA 12.8)
pip install tilelang -f https://tile-ai.github.io/whl/nightly/cu128/

# Megatron-LM: install from source in editable mode so we can apply patches
cd "${MEGATRON_DIR}"
pip install -e .

# Install miles (this repo) in editable mode
cd "${MILES_DIR}"
pip install -e .

# Workaround for PyTorch issue #168167: pin a known-compatible cuDNN version
pip install "nvidia-cudnn-cu12==9.16.0.29"

# Megatron-LM still requires numpy 1.x for now
pip install "numpy<2"
```

## Step 3. Apply the SGLang and Megatron patches

Uni-OPD ships a small set of patches against pinned upstream commits (located under [`miles/docker/patch/v0.5.7`](../miles/docker/patch)). Apply them after the Python packages are installed:

```bash
# SGLang patch
cd "${SGLANG_DIR}"
git apply "${MILES_DIR}/docker/patch/v0.5.7/sglang_psp.patch"

# Megatron-LM patch
cd "${MEGATRON_DIR}"
git apply "${MILES_DIR}/docker/patch/v0.5.7/megatron.patch"
```

## Verification

Once everything is installed, you can do a quick smoke test:

```bash
conda activate Uni-OPD
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.cuda.is_available())"
python -c "import flash_attn, transformer_engine, sglang; print('flash_attn / TE / sglang OK')"
python -c "import megatron, miles; print('megatron / miles OK')"
```

If all three commands succeed, the training environment is ready and you can move on to launching a training job under [`exps/scripts/OPD`](../exps/scripts/OPD).
