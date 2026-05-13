<div align="center">

# Uni-OPD: Unifying On-Policy Distillation with a Dual-Perspective Recipe <!-- omit in toc -->

<a href='https://arxiv.org/abs/2605.03677'>
<img src='https://img.shields.io/badge/Paper-Arxiv-purple'></a>
<a href='https://github.com/WenjinHou/Uni-OPD/blob/main/LICENSE'>
<img src='https://img.shields.io/badge/LICENSE-Apache_2.0-yellow'></a>

<a href="/docs/README_zh.md">中文</a> | <b>English</b>

<!--
**Wenjin Hou\*<sup>1</sup>**,&emsp;
**Shangpin Peng\*<sup>3</sup>**,&emsp;
**Weinong Wang<sup>3,†</sup>**,&emsp;
**Zheng Ruan<sup>3</sup>**,&emsp;
**Yue Zhang<sup>1</sup>**,&emsp;
**Zhenglin Zhou<sup>1</sup>**

**Mingqi Gao<sup>3</sup>**,&emsp;
**Yifei Chen<sup>3</sup>**,&emsp;
**Kaiqi Wang<sup>3</sup>**,&emsp;
**Hongming Yang<sup>3</sup>**,&emsp;
**Chengquan Zhang<sup>3</sup>**,&emsp;
**Zhuotao Tian<sup>2</sup>**

**Han Hu<sup>3,‡</sup>**,&emsp;
**Yi Yang<sup>1</sup>**,&emsp;
**Fei Wu<sup>1</sup>**,&emsp;
**Hehe Fan<sup>1,✉️</sup>**

<sup>1</sup>Zhejiang University&emsp;
<sup>2</sup>Shenzhen Loop Area Institute&emsp;
<sup>3</sup>LLM Department, Tencent

\*Equal contribution&emsp;<sup>†</sup>Project lead&emsp;<sup>‡</sup>Advisor&emsp;<sup>✉️</sup>Corresponding author
-->

</div>

## 🎊 News <!-- omit in toc -->

- [2026.05.13] 🚀 We open-source the code and training scripts for OPD.
- [2026.05.05] 📖 We release our paper on [ArXiv](https://arxiv.org/abs/2605.03677).

## 🚀 Overview <!-- omit in toc -->

**Uni-OPD** is a unified On-Policy Distillation (OPD) framework that consolidates the capabilities of specialized expert teachers into a single student model, generalizing across **LLMs and MLLMs**. We identify two fundamental bottlenecks that limit effective OPD:

1. **Insufficient exploration of informative student-generated states**, and
2. **Unreliable teacher supervision for student rollouts**.

To address them, Uni-OPD introduces a **dual-perspective optimization recipe** that jointly improves student exploration (via offline difficulty-aware and online correctness-aware data balancing) and teacher reliability (via an outcome-guided margin calibration mechanism). Extensive experiments on **5 domains and 16 benchmarks**, covering single-/multi-teacher, strong-to-weak, and cross-modal distillation, verify the effectiveness and versatility of Uni-OPD.

<table align="center">
    <p align="center">
      <img src="/docs/figures/teaser.png" width="80%" />
    </p>
</table>

## 📌 Contents <!-- omit in toc -->

- [🔑 Key Features](#-key-features)
- [📚 Dataset](#-dataset)
- [💻 Environment Setup](#-environment-setup)
- [⚙️ Training](#️-training)
- [📈 Evaluation](#-evaluation)
- [📝 Citation](#-citation)

## 🔑 Key Features

- **A unified OPD framework across LLMs and MLLMs.** Uni-OPD consolidates knowledge from one or several expert teachers into a single student model and works seamlessly across single-teacher, multi-teacher, strong-to-weak, and cross-modal (text + multimodal) distillation settings.
<table align="center">
    <p align="center">
      <img src="/docs/figures/framework.png" width="85%" />
    </p>
</table>

- **Student-perspective: offline difficulty-aware data balancing.** We selectively upsample medium-difficulty prompts to reshape the training corpus into a more balanced difficulty distribution while preserving data diversity. This enables the student to generate more informative trajectories and explore a broader solution space.
<table align="center">
    <p align="center">
      <img src="/docs/figures/offline_data_balancing.png" width="80%" />
    </p>
</table>

- **Student-perspective: online correctness-aware data balancing.** During training, we dynamically filter and reshape rollout batches to maintain a balanced ratio between correct and incorrect trajectories, preventing the student from collapsing onto trivially correct samples or being overwhelmed by uniformly failed ones.
<table align="center">
    <p align="center">
      <img src="/docs/figures/online_data_balancing.png" width="60%" />
    </p>
</table>

- **Teacher-perspective: outcome-guided margin calibration.** We show that reliable token-level teacher supervision largely depends on whether its trajectory-level aggregation remains _order-consistent_ with the outcome reward. Uni-OPD uses the outcome reward as a global anchor to calibrate the teacher's per-token margins, restoring order consistency between correct and incorrect trajectories.
<table align="center">
    <p align="center">
      <img src="/docs/figures/margin_calibration.png" width="85%" />
    </p>
</table>

- **Stable training dynamics and strong empirical results.** The dual-perspective recipe yields smoother training curves and consistent gains over strong OPD/RL baselines across math, code, chart, and general multimodal reasoning benchmarks. See the paper for the full set of results.
<table align="center">
    <p align="center">
      <img src="/docs/figures/train_dynamics.png" width="80%" />
    </p>
</table>

## 📚 Dataset

The dataset we use for training and evaluation in Uni-OPD is a combination of publicly available resources:

- **Text training data (Math + Code).** We use the same training data as [G-OPD](https://github.com/RUCBM/G-OPD), available at [🤗 Keven16/G-OPD-Training-Data](https://huggingface.co/datasets/Keven16/G-OPD-Training-Data).
  - The math part is sourced from the **DeepMath** dataset.
  - The code part is sourced from the **code subset of the Eurus-2-RL** dataset.

- **Multimodal training data.** We use a mixture of:
  - [🤗 OpenMMReasoner/OpenMMReasoner-RL-74K](https://huggingface.co/datasets/OpenMMReasoner/OpenMMReasoner-RL-74K),
  - [🤗 HuggingFaceM4/ChartQA](https://huggingface.co/datasets/HuggingFaceM4/ChartQA), and
  - [InfographicVQA](https://www.docvqa.org).

<!--
## 📦 Model Weights

-->

## 💻 Environment Setup

We provide step-by-step instructions for both the training and evaluation environments:

- **Training environment** — see [docs/build_env.md](docs/build_env.md). It walks through preparing the conda env (`Uni-OPD`, Python 3.12), installing required packages, and applying the SGLang & Megatron patches shipped under [`miles/docker/patch`](miles/docker/patch).
- **Evaluation environment** — see [docs/build_eval_env.md](docs/build_eval_env.md). It covers two separate conda envs:
  - `Uni-OPD-LLM-Eval` for text evaluation (built on top of [G-OPD](https://github.com/RUCBM/G-OPD)), and
  - `Uni-OPD-LMMS-Eval` for multimodal evaluation (built on top of [lmms-eval](https://github.com/evolvinglmms-lab/lmms-eval)).

A typical post-setup layout looks like:

```text
- Uni-OPD/                  # this repository
  - miles/                  # RL / OPD training framework
  - Megatron-LM/            # training backend
  - sglang/                 # inference / rollout backend
  - G-OPD/                  # text-side evaluation (cloned for eval env)
  - lmms-eval/              # multimodal evaluation (cloned for eval env)
```

## ⚙️ Training

All training and implementation in Uni-OPD is built on top of the [miles](https://github.com/radixark/miles) framework. For a summary of the modifications we made to miles, see [docs/miles_modifications.md](docs/miles_modifications.md).

We release the full set of training scripts used in the paper under [`exps/scripts/OPD`](exps/scripts/OPD), grouped by distillation setting:

| Setting        | Path                                                                 | Description                                                                |
| -------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Single-teacher | [`exps/scripts/OPD/single_teacher`](exps/scripts/OPD/single_teacher) | Math / Code distillation with Qwen3-1.7B & Qwen3-4B students.              |
| Multi-teacher  | [`exps/scripts/OPD/multi_teacher`](exps/scripts/OPD/multi_teacher)   | Joint Math + Code distillation from multiple expert teachers.              |
| Strong-to-weak | [`exps/scripts/OPD/strong_to_weak`](exps/scripts/OPD/strong_to_weak) | Distilling a stronger teacher (Qwen3-A3B-Instruct) into a smaller student. |

A minimal launch command looks like:

```bash
# Activate the training conda env built via docs/build_env.md
conda activate Uni-OPD

# Example: single-teacher Math distillation, 4B student
bash exps/scripts/OPD/single_teacher/0413/Qwen3_Stu_4B_Math_Uni_OPD.sh \
    --rollout-batch-size 64 \
    --sample-n 16 \
    --lr 1e-6
```

> Before running, please
>
> 1. update the model / data paths at the top of the script (and inside the corresponding YAML under `configs/`) to point to your local checkpoints and dataset files.
> 2. Launch teacher server(s) using `miles/Uni_OPD_utils/scripts/server/run_sglang_server.sh` and put relevent addresses in `miles/Uni_OPD_utils/OPD_reward/teacher_server_list.json`.

## 📈 Evaluation

Evaluation is performed in the dedicated evaluation environments described in [docs/build_eval_env.md](docs/build_eval_env.md):

- **LLM benchmarks** (math & code) follow the [G-OPD](https://github.com/RUCBM/G-OPD) evaluation pipeline.
- **MLLM benchmarks** (ChartQA, InfographicVQA, MathVision, LogicVista, etc.) follow the [lmms-eval](https://github.com/evolvinglmms-lab/lmms-eval) pipeline.

Please refer to the upstream repositories for the per-benchmark commands.

## 📝 Citation

If you find our paper / code helpful, please consider citing our work 📝 and starring this repository ⭐️!

```bibtex
@article{hou2026uni,
  title   = {Uni-OPD: Unifying On-Policy Distillation with a Dual-Perspective Recipe},
  author  = {Hou, Wenjin and Peng, Shangpin and Wang, Weinong and Ruan, Zheng and Zhang, Yue and Zhou, Zhenglin and Gao, Mingqi and Chen, Yifei and Wang, Kaiqi and Yang, Hongming and others},
  journal = {arXiv preprint arXiv:2605.03677},
  year    = {2026}
}
```

## 🙏 Acknowledgement <!-- omit in toc -->

- [G-OPD](https://github.com/RUCBM/G-OPD): an excellent open-source project on on-policy distillation; we reuse its text-side training data and evaluation pipeline.
- [miles](https://github.com/radixark/miles): the powerful RL training framework on top of which we build Uni-OPD.
- [Megatron-LM](https://github.com/NVIDIA/Megatron-LM) and [SGLang](https://github.com/sgl-project/sglang): the training and rollout backends used throughout this project.
- [lmms-eval](https://github.com/evolvinglmms-lab/lmms-eval): the multimodal evaluation framework we adopt for MLLM benchmarks.

## 📧 Contact us <!-- omit in toc -->

If you have any questions, comments, or suggestions, please feel free to open an issue or PR. Contributions and discussions that help advance research in this area are very welcome!

## License <!-- omit in toc -->

[Apache License 2.0](/LICENSE)
