# Uni-OPD 评测环境构建

<b>中文</b> | <a href="/docs/build_eval_env.md">English</a>

本文档介绍如何从零开始搭建 **Uni-OPD 的评测环境**，覆盖了复现论文中评测结果所需的全部依赖。

开始之前，请先准备好：

- 一份 **Uni-OPD** 仓库的本地克隆；
- 已安装 **Anaconda** 或 **Miniconda**。

按照下面的步骤完成后，你将得到：

```text
- <YOUR PATH TO UNI OPD>/        # 仓库根目录
  - G-OPD/                       # 文本侧评测流程（克隆获得）
  - lmms-eval/                   # 多模态评测流程（克隆获得）
  ...
```

以及 **两个** 评测专用的 conda 环境：

- **`Uni-OPD-LLM-Eval`** —— 用于 LLM（数学 / 代码）评测，基于 [G-OPD](https://github.com/RUCBM/G-OPD)。
- **`Uni-OPD-LMMS-Eval`** —— 用于 MLLM 评测，基于 [lmms-eval](https://github.com/evolvinglmms-lab/lmms-eval)。

> 我们刻意将两个环境分开，是因为它们对 `vllm` / `sglang` / `transformers` 的版本约束并不完全兼容。

## 1. LLM 评测环境

### 1.1 克隆必要的代码库

```bash
cd "<YOUR PATH TO UNI OPD>"
git clone https://github.com/RUCBM/G-OPD
```

### 1.2 创建 conda 环境并安装依赖

```bash
export G_OPD_PATH="<YOUR PATH TO UNI OPD>/G-OPD"
export CONDA_PATH="<YOUR PATH TO CONDA>"

source "${CONDA_PATH}/bin/activate"
conda create -n Uni-OPD-LLM-Eval python=3.10.20 -y
conda activate Uni-OPD-LLM-Eval

# 通过 G-OPD 提供的脚本安装 vllm / sglang / mcore
USE_MEGATRON=0 bash "${G_OPD_PATH}/verl/scripts/install_vllm_sglang_mcore.sh"

# 数学与代码评测所需工具
pip install math-verify evalplus pebble

# 以 editable 模式安装 G-OPD 修改过的 evalplus
SETUPTOOLS_SCM_PRETEND_VERSION=0.3.1 pip install -e "${G_OPD_PATH}/code_eval/coding/evalplus"
```

完成本步后，便可以直接通过 `${G_OPD_PATH}` 下的脚本启动数学基准（如 AIME、MATH-500、DeepMath）和代码基准（如 HumanEval+、MBPP+）的评测。

## 2. MLLM 评测环境

### 2.1 克隆必要的代码库

```bash
cd "<YOUR PATH TO UNI OPD>"
git clone https://github.com/evolvinglmms-lab/lmms-eval
```

### 2.2 创建 conda 环境并安装依赖

```bash
export LMMS_EVAL_PATH="<YOUR PATH TO UNI OPD>/lmms-eval"
export CONDA_PATH="<YOUR PATH TO CONDA>"

source "${CONDA_PATH}/bin/activate"
conda create -n Uni-OPD-LMMS-Eval python=3.12.13 -y
conda activate Uni-OPD-LMMS-Eval

# 推理 / 评测核心依赖
pip install "vllm>=0.13.0" qwen-vl-utils decord math-verify

# 以 editable 模式安装 lmms-eval（带全部 extras）
cd "${LMMS_EVAL_PATH}"
pip install -e ".[all]"

# latex2sympy2_extended 取代了旧版 latex2sympy2，
# 卸载旧包以避免命名空间冲突。
pip install latex2sympy2_extended
pip uninstall latex2sympy2 -y

# 图表 / 文档类基准所需的额外依赖
pip install jieba distance apted Polygon3 nltk
python -c "import nltk; nltk.download('wordnet'); nltk.download('omw-1.4')"
```

完成本步后，便可以使用标准的 `lmms-eval` CLI 启动 **ChartQA**、**InfographicVQA**、**MathVision**、**LogicVista** 等 MLLM 基准的评测。

## 自检

可以分别对两个环境做一次快速自检：

```bash
# LLM 评测环境
conda activate Uni-OPD-LLM-Eval
python -c "import vllm, sglang, math_verify, evalplus; print('LLM eval env OK')"

# MLLM 评测环境
conda activate Uni-OPD-LMMS-Eval
python -c "import vllm, lmms_eval, qwen_vl_utils, decord; print('MLLM eval env OK')"
```

如果两条命令都能成功执行，说明评测环境已就绪，可以开始复现论文中列出的各项基准。
