#!/usr/bin/env bash
# 生成关卡库：编译导出器并产出 godot/levels.json（每档 per_band 关，默认 3）。
# 用法（仓库根或任意目录）：bash engine/gen_levels.sh [per_band]
set -e
cd "$(dirname "$0")/.."
clang++ -std=c++20 -O2 -pthread engine/export_levels.cpp -o /tmp/omc_export_levels
/tmp/omc_export_levels "${1:-3}" godot/levels.json
echo "关卡库已生成 → godot/levels.json"
