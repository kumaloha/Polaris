#!/usr/bin/env bash
set -euo pipefail

# Start Polaris with the generated, solver-gated level pack instead of the
# default production library.
#
# Equivalent manual command:
#   godot --path godot -- --levels res://levels.generated.json

cd "$(dirname "${BASH_SOURCE[0]}")/.."
exec godot --path . -- --levels res://levels.generated.json "$@"
