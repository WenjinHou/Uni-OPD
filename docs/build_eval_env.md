# Uni-OPD Evaluation Environment Setup

<a href="/docs/build_eval_env_zh.md">中文</a> | <b>English</b>

This document walks through building the **Uni-OPD evaluation environments** from scratch, including every dependency required to reproduce the evaluation results in the paper.

Before you start, please prepare:

- A clone of the **Uni-OPD** repository.
- A working **Anaconda** or **Miniconda** installation.

After following the steps below, you will end up with:

```text
- <YOUR PATH TO UNI OPD>/        # repo root
  - G-OPD/                       # text-side evaluation pipeline (cloned)
  - lmms-eval/                   # multimodal evaluation pipeline (cloned)
  ...
```

and **two** dedicated conda environments:

- **`Uni-OPD-LLM-Eval`** — for LLM (math / code) benchmarks, built on top of [G-OPD](https://github.com/RUCBM/G-OPD).
- **`Uni-OPD-LMMS-Eval`** — for MLLM benchmarks, built on top of [lmms-eval](https://github.com/evolvinglmms-lab/lmms-eval).

> We deliberately keep the two environments separate because their `vllm` / `sglang` / `transformers` version constraints are not fully compatible.

## 1. LLM Evaluation Environment

### 1.1 Clone the required repositories

```bash
cd "<YOUR PATH TO UNI OPD>"
git clone https://github.com/RUCBM/G-OPD
```

### 1.2 Create the conda env and install dependencies

```bash
export G_OPD_PATH="<YOUR PATH TO UNI OPD>/G-OPD"
export CONDA_PATH="<YOUR PATH TO CONDA>"

source "${CONDA_PATH}/bin/activate"
conda create -n Uni-OPD-LLM-Eval python=3.10.20 -y
conda activate Uni-OPD-LLM-Eval

# Install vllm / sglang / mcore via the helper script shipped by G-OPD
USE_MEGATRON=0 bash "${G_OPD_PATH}/verl/scripts/install_vllm_sglang_mcore.sh"

# Math + code evaluation utilities
pip install math-verify evalplus pebble

# Install G-OPD's patched evalplus in editable mode
SETUPTOOLS_SCM_PRETEND_VERSION=0.3.1 pip install -e "${G_OPD_PATH}/code_eval/coding/evalplus"
```

After this step, math benchmarks (e.g. AIME, MATH-500, DeepMath) and code benchmarks (e.g. HumanEval+, MBPP+) can be launched directly via the scripts inside `${G_OPD_PATH}`.

## 2. MLLM Evaluation Environment

### 2.1 Clone the required repositories

```bash
cd "<YOUR PATH TO UNI OPD>"
git clone https://github.com/evolvinglmms-lab/lmms-eval
```

### 2.2 Create the conda env and install dependencies

```bash
export LMMS_EVAL_PATH="<YOUR PATH TO UNI OPD>/lmms-eval"
export CONDA_PATH="<YOUR PATH TO CONDA>"

source "${CONDA_PATH}/bin/activate"
conda create -n Uni-OPD-LMMS-Eval python=3.12.13 -y
conda activate Uni-OPD-LMMS-Eval

# Core inference / evaluation deps
pip install "vllm>=0.13.0" qwen-vl-utils decord math-verify

# Install lmms-eval in editable mode with all extras
cd "${LMMS_EVAL_PATH}"
pip install -e ".[all]"

# latex2sympy2_extended replaces the legacy latex2sympy2;
# uninstall the old package to avoid namespace clashes.
pip install latex2sympy2_extended
pip uninstall latex2sympy2 -y

# Extra deps required by chart / document benchmarks
pip install jieba distance apted Polygon3 nltk
python -c "import nltk; nltk.download('wordnet'); nltk.download('omw-1.4')"
```

After this step, MLLM benchmarks such as **ChartQA**, **InfographicVQA**, **MathVision**, **LogicVista**, etc. can be launched via the standard `lmms-eval` CLI.

## Verification

A quick smoke test for both environments:

```bash
# LLM eval env
conda activate Uni-OPD-LLM-Eval
python -c "import vllm, sglang, math_verify, evalplus; print('LLM eval env OK')"

# MLLM eval env
conda activate Uni-OPD-LMMS-Eval
python -c "import vllm, lmms_eval, qwen_vl_utils, decord; print('MLLM eval env OK')"
```

If both succeed, the evaluation environments are ready for the benchmarks listed in the paper.
