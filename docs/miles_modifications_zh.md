# Uni-OPD 对 miles 的修改说明

<b>中文</b> | <a href="/docs/miles_modifications.md">English</a>

Uni-OPD 的所有训练与实现均基于 [miles](https://github.com/radixark/miles) 框架，以 commit [`5f8c6de`](https://github.com/radixark/miles/commit/5f8c6deecaa774a546448d44500c3de4a75477fd) 为基础进行修改。

主要改动如下：

- `miles/utils/data.py` — 适配从 YAML 配置文件读取所有训练数据及其对应 teacher model 的映射关系。
- `miles/utils/arguments.py` — 新增 Margin Shift、Greedy Margin Mask 以及 Online Data Balance 相关的命令行参数。
- `miles/backends/training_utils/loss.py` — 上述功能的具体实现。
- `Uni_OPD_utils/` — Uni-OPD 专用的工具模块。
  - `Uni_OPD_utils/OPD_reward/` — Uni-OPD 的 token 级别 reward 相关实现。
  - `Uni_OPD_utils/outcome_reward/` — Uni-OPD 的 outcome reward 相关实现。
  - `Uni_OPD_utils/ray_launcher.py` — 启动训练任务的入口脚本。
