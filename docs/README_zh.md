<div align="center">

# Uni-OPD: Unifying On-Policy Distillation with a Dual-Perspective Recipe <!-- omit in toc -->

<a href='https://arxiv.org/abs/2605.03677'>
<img src='https://img.shields.io/badge/论文-Arxiv-purple'></a>
<a href='https://github.com/WenjinHou/Uni-OPD/blob/main/LICENSE'>
<img src='https://img.shields.io/badge/许可证-Apache_2.0-yellow'></a>

<b>中文</b> | <a href="/README.md">English</a>

<!--
**[Wenjin Hou](mailto:houwj17@gmail.com)\*<sup>1</sup>**,&emsp;
**Shangpin Peng\*<sup>3</sup>**,&emsp;
**[Weinong Wang](mailto:weinong.wang@hotmail.com)<sup>3,†</sup>**,&emsp;
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
**[Hehe Fan](mailto:hehefan@zju.edu.cn)<sup>1,✉️</sup>**

<sup>1</sup>浙江大学&emsp;
<sup>2</sup>深圳河套创新研究院&emsp;
<sup>3</sup>腾讯大语言模型部

\* 共同第一作者&emsp;<sup>†</sup> 项目负责人&emsp;<sup>‡</sup> 指导老师&emsp;<sup>✉️</sup> 通讯作者
-->

</div>

## 🎊 新闻 <!-- omit in toc -->

- [2026.05.13] 🚀 我们开源了 OPD 的代码和训练脚本。

- [2026.05.05] 📖 我们在 [ArXiv](https://arxiv.org/abs/2605.03677) 上发布了论文。

## 🚀 概览 <!-- omit in toc -->

**Uni-OPD** 是一个统一的在线策略蒸馏（On-Policy Distillation, OPD）框架，能够将多个领域专家教师的能力整合到单一学生模型中，并同时支持 **大语言模型（LLM）和多模态大模型（MLLM）**。我们识别出限制 OPD 效果的两个根本瓶颈：

1. **学生对信息丰富状态的探索不足**；
2. **教师对学生采样轨迹的监督不可靠**。

为此，Uni-OPD 提出了**双视角优化方案**：从学生视角通过离线难度感知与在线正确性感知的数据均衡来促进探索；从教师视角通过结果引导的边际校准（margin calibration）机制来恢复 token 级监督与最终结果奖励的顺序一致性。我们在 **5 个领域、16 个基准** 上进行了全面实验，覆盖单教师 / 多教师蒸馏、强→弱蒸馏以及跨模态蒸馏等多种设置，验证了 Uni-OPD 的有效性与通用性。

<table align="center">
    <p align="center">
      <img src="/docs/figures/teaser.png" width="80%" />
    </p>
</table>

## 📌 目录 <!-- omit in toc -->

- [🔑 主要特性](#-主要特性)
- [📚 数据集](#-数据集)
- [💻 环境配置](#-环境配置)
- [⚙️ 训练](#️-训练)
- [📈 评估](#-评估)
- [📝 引用](#-引用)

## 🔑 主要特性

- **统一的 LLM / MLLM OPD 框架**。Uni-OPD 可以将一个或多个专家教师的能力整合到单一学生模型中，原生支持单教师、多教师、强→弱以及跨模态（文本 + 多模态）等多种蒸馏场景。
<table align="center">
    <p align="center">
      <img src="/docs/figures/framework.png" width="85%" />
    </p>
</table>

- **学生视角 1：离线难度感知数据均衡**。通过选择性上采样中等难度样本，在保留多样性与难度跨度的同时重塑更均衡的难度谱，从而促使学生生成更具信息量的轨迹并探索更广阔的解空间。
<table align="center">
    <p align="center">
      <img src="/docs/figures/offline_data_balancing.png" width="80%" />
    </p>
</table>

- **学生视角 2：在线正确性感知数据均衡**。在训练过程中，我们动态过滤并重塑 rollout batch，维持正确轨迹与错误轨迹之间的合理比例，避免学生坍缩到「全部正确」的简单样本，也防止被「全部失败」的样本完全淹没。
<table align="center">
    <p align="center">
      <img src="/docs/figures/online_data_balancing.png" width="60%" />
    </p>
</table>

- **教师视角：结果引导的边际校准**。我们发现教师 token 级监督是否可靠，关键在于其 **轨迹级聚合是否与最终结果奖励保持顺序一致**。Uni-OPD 利用结果奖励作为全局锚点对教师的逐 token 边际进行校准，恢复正确与错误轨迹之间的顺序一致性。
<table align="center">
    <p align="center">
      <img src="/docs/figures/margin_calibration.png" width="85%" />
    </p>
</table>

<!--
- **更稳定的训练动态与更强的实证表现**。该双视角方案带来更平滑的训练曲线，以及在数学、代码、图表与通用多模态推理等基准上相对强 OPD/RL 基线的稳定提升。完整结果请参阅论文。
<table align="center">
    <p align="center">
      <img src="/docs/figures/train_dynamics.png" width="80%" />
    </p>
</table>
-->

## 📚 数据集

我们在 Uni-OPD 的训练与评测中使用了多个公开数据资源的组合：

- **文本训练数据（Math + Code）**：与 [G-OPD](https://github.com/RUCBM/G-OPD) 使用相同的数据，可在 [🤗 Keven16/G-OPD-Training-Data](https://huggingface.co/datasets/Keven16/G-OPD-Training-Data) 获取。
  - 数学部分来自 **DeepMath** 数据集；
  - 代码部分来自 **Eurus-2-RL 的 code 子集**。

- **多模态训练数据**：我们使用了以下数据的混合：
  - [🤗 OpenMMReasoner/OpenMMReasoner-RL-74K](https://huggingface.co/datasets/OpenMMReasoner/OpenMMReasoner-RL-74K)，
  - [🤗 HuggingFaceM4/ChartQA](https://huggingface.co/datasets/HuggingFaceM4/ChartQA)，
  - [InfographicVQA](https://www.docvqa.org)。

<!--
## 📦 模型权重

-->

## 💻 环境配置

我们提供了从零开始构建训练与评估环境的完整说明：

- **训练环境** —— 见 [docs/build_env_zh.md](build_env_zh.md)。涵盖 conda 环境（`Uni-OPD`，Python 3.12）的创建，以及 PyTorch / SGLang / Megatron-LM / TransformerEngine / Apex / Flash-Attention / mbridge 等依赖的安装，并应用 [`miles/docker/patch`](../miles/docker/patch) 中的 SGLang 与 Megatron 补丁。
- **评估环境** —— 见 [docs/build_eval_env_zh.md](build_eval_env_zh.md)。包含两个独立 conda 环境：
  - `Uni-OPD-LLM-Eval`：基于 [G-OPD](https://github.com/RUCBM/G-OPD) 的文本侧评测环境；
  - `Uni-OPD-LMMS-Eval`：基于 [lmms-eval](https://github.com/evolvinglmms-lab/lmms-eval) 的多模态评测环境。

按上述文档配置后，典型的目录结构如下：

```text
- Uni-OPD/                  # 本仓库
  - miles/                  # RL / OPD 训练框架
  - Megatron-LM/            # 训练后端
  - sglang/                 # 推理 / rollout 后端
  - G-OPD/                  # 文本评测（评估环境会克隆）
  - lmms-eval/              # 多模态评测（评估环境会克隆）
```

## ⚙️ 训练

Uni-OPD 的所有训练与实现均基于 [miles](https://github.com/radixark/miles) 框架，详情请参阅 [docs/miles_modifications_zh.md](miles_modifications_zh.md)。

我们将论文中所有训练脚本完整开源在 [`exps/scripts/OPD`](../exps/scripts/OPD) 下，按蒸馏设置分为三类：

| 设置       | 路径                                                                    | 说明                                                           |
| ---------- | ----------------------------------------------------------------------- | -------------------------------------------------------------- |
| 单教师蒸馏 | [`exps/scripts/OPD/single_teacher`](../exps/scripts/OPD/single_teacher) | 以 Qwen3-1.7B / Qwen3-4B 作为学生进行 Math / Code 单教师蒸馏。 |
| 多教师蒸馏 | [`exps/scripts/OPD/multi_teacher`](../exps/scripts/OPD/multi_teacher)   | 来自多个专家教师的 Math + Code 联合蒸馏。                      |
| 强→弱蒸馏  | [`exps/scripts/OPD/strong_to_weak`](../exps/scripts/OPD/strong_to_weak) | 将更强的教师（Qwen3-A3B-Instruct）蒸馏到更小的学生模型。       |

每个脚本都是自包含的：会启动 SGLang 教师服务（或通过 `--rm-url` 连接外部教师服务）、拉起 Ray，并以 `configs/` 下对应的 YAML 配置调用 `miles` 训练器。常用参数（rollout batch size、sample-N、学习率、ε-clip、advantage-shift、在线过滤等）都集中在每个 `*.sh` 顶部，完整的 CLI 参数说明可参考脚本顶部的 `usage` 注释块。

最小启动命令示例：

```bash
# 激活按 docs/build_env_zh.md 创建的训练环境
conda activate Uni-OPD

# 示例：4B 学生 + 单教师 Math 蒸馏
bash exps/scripts/OPD/single_teacher/0413/Qwen3_Stu_4B_Math_Uni_OPD.sh \
    --rollout-batch-size 64 \
    --sample-n 16 \
    --lr 1e-6
```

> 运行前请先把脚本顶部及 `configs/` 中对应 YAML 内的模型路径、数据路径替换为本地的实际路径。

## 📈 评估

评估在 [docs/build_eval_env_zh.md](build_eval_env_zh.md) 中描述的专用评测环境中进行：

- **LLM 基准**（数学与代码）沿用 [G-OPD](https://github.com/RUCBM/G-OPD) 的评测流程；
- **MLLM 基准**（ChartQA、InfographicVQA、MathVision、LogicVista 等）沿用 [lmms-eval](https://github.com/evolvinglmms-lab/lmms-eval) 的评测流程。

具体每个基准的评测命令请参考上述上游仓库；我们直接采用默认评测配置。

## 📝 引用

如果您觉得我们的论文 / 代码对您有帮助，欢迎引用我们的论文 📝 并为本仓库点 ⭐️！

```bibtex
@article{hou2026uni,
  title   = {{Uni-OPD}: Unifying On-Policy Distillation with a Dual-Perspective Recipe},
  author  = {Hou, Wenjin and Peng, Shangpin and Wang, Weinong and Ruan, Zheng and Zhang, Yue and Zhou, Zhenglin and Gao, Mingqi and Chen, Yifei and Wang, Kaiqi and Yang, Hongming and Zhang, Chengquan and Tian, Zhuotao and Hu, Han and Yang, Yi and Wu, Fei and Fan, Hehe},
  journal = {arXiv preprint arXiv:2605.03677},
  year    = {2026}
}
```

## 🙏 致谢 <!-- omit in toc -->

- [G-OPD](https://github.com/RUCBM/G-OPD)：一个出色的在线策略蒸馏开源项目，我们复用了其文本侧训练数据与评测流程。
- [miles](https://github.com/radixark/miles)：Uni-OPD 所基于的强大 RL 训练框架。
- [Megatron-LM](https://github.com/NVIDIA/Megatron-LM) 与 [SGLang](https://github.com/sgl-project/sglang)：本项目使用的训练后端与 rollout 后端。
- [lmms-eval](https://github.com/evolvinglmms-lab/lmms-eval)：我们在 MLLM 基准上采用的多模态评测框架。

## 📧 联系我们 <!-- omit in toc -->

如有任何问题、意见或建议，欢迎提交 issue 或 PR。我们非常欢迎所有有助于推动该方向研究的讨论与贡献！

## License <!-- omit in toc -->

[Apache License 2.0](/LICENSE)
