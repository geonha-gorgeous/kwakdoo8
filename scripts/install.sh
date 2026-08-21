#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
requested_version="${1:-$(tr -d '[:space:]' < "${repo_root}/LATEST")}"
source_dir="${repo_root}/versions/${requested_version}/dupal"

if [[ ! -f "${source_dir}/pet.json" || ! -f "${source_dir}/spritesheet.webp" ]]; then
  echo "Unknown or incomplete version: ${requested_version}" >&2
  echo "Available versions:" >&2
  "${script_dir}/list-versions.sh" >&2
  exit 1
fi

codex_root="${CODEX_HOME:-${HOME}/.codex}"
target_dir="${codex_root}/pets/dupal"
backup_root="${codex_root}/pets/.dupal-backups"

if [[ -d "${target_dir}" ]] && find "${target_dir}" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  backup_dir="${backup_root}/$(date '+%Y%m%d-%H%M%S')"
  mkdir -p "${backup_dir}"
  cp -R "${target_dir}/." "${backup_dir}/"
  echo "Backed up the active package to ${backup_dir}"
fi

mkdir -p "${target_dir}"
install -m 0644 "${source_dir}/pet.json" "${target_dir}/pet.json"
install -m 0644 "${source_dir}/spritesheet.webp" "${target_dir}/spritesheet.webp"

echo "Installed 두팔 ${requested_version} to ${target_dir}"
echo "Restart or refresh the desktop app, then select 두팔."
