#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

find "${repo_root}/versions" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -V
