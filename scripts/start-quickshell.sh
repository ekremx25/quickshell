#!/usr/bin/env bash
set -euo pipefail

config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Reuse the existing configuration instance instead of competing for desktop services.
exec quickshell --no-duplicate --path "$config_dir/shell.qml" "$@"
