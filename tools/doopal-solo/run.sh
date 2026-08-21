#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
binary_path="${script_dir}/build/doopal-solo"

if [[ ! -x "${binary_path}" || "${script_dir}/DoopalSolo.swift" -nt "${binary_path}" ]]; then
  "${script_dir}/build.sh" >/dev/null
fi

exec "${binary_path}" "$@"
