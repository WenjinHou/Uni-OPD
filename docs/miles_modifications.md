# Uni-OPD Modifications to miles

<a href="/docs/miles_modifications_zh.md">中文</a> | <b>English</b>

All training and implementation in Uni-OPD is built on top of the [miles](https://github.com/radixark/miles) framework, based on commit [`5f8c6de`](https://github.com/radixark/miles/commit/5f8c6deecaa774a546448d44500c3de4a75477fd).

The key modifications are:

- `miles/utils/data.py` — adapted to read all training datasets and their teacher-model mappings from a YAML configuration file.
- `miles/utils/arguments.py` — added CLI arguments for Margin Shift, Greedy Margin Mask, and Online Data Balance.
- `miles/backends/training_utils/loss.py` — concrete implementation of the above features.
- `Uni_OPD_utils/` — utility modules specific to Uni-OPD.
  - `Uni_OPD_utils/OPD_reward/` — token-level reward implementation for Uni-OPD.
  - `Uni_OPD_utils/outcome_reward/` — outcome reward implementation for Uni-OPD.
  - `Uni_OPD_utils/ray_launcher.py` — entry-point script for launching training runs.
