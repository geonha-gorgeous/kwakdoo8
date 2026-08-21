#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
requested_version="${1:-$(tr -d '[:space:]' < "${repo_root}/LATEST")}"
version_dir="${repo_root}/versions/${requested_version}"

package_dirs=()
if [[ -d "${version_dir}" ]]; then
  for candidate in "${version_dir}"/*; do
    if [[ -d "${candidate}" && -f "${candidate}/pet.json" && -f "${candidate}/spritesheet.webp" ]]; then
      package_dirs+=("${candidate}")
    fi
  done
fi

if [[ "${#package_dirs[@]}" -ne 1 ]]; then
  echo "Unknown or incomplete version: ${requested_version}" >&2
  echo "Available versions:" >&2
  "${script_dir}/list-versions.sh" >&2
  exit 1
fi

source_dir="${package_dirs[0]}"
pet_id="$(basename "${source_dir}")"
display_name="$(sed -n 's/^[[:space:]]*"displayName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${source_dir}/pet.json" | head -n 1)"
display_name="${display_name:-${pet_id}}"

codex_root="${CODEX_HOME:-${HOME}/.codex}"
target_dir="${codex_root}/pets/${pet_id}"
backup_root="${codex_root}/pets/.${pet_id}-backups"
timestamp="$(date '+%Y%m%d-%H%M%S')-$$"

if [[ -d "${target_dir}" ]] && find "${target_dir}" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  backup_dir="${backup_root}/${timestamp}"
  mkdir -p "${backup_dir}"
  cp -R "${target_dir}/." "${backup_dir}/"
  echo "Backed up the active package to ${backup_dir}"
fi

legacy_pet_id=""
case "${pet_id}" in
  doopal) legacy_pet_id="dupal" ;;
  dupal) legacy_pet_id="doopal" ;;
esac

if [[ -n "${legacy_pet_id}" ]]; then
  legacy_target="${codex_root}/pets/${legacy_pet_id}"
  if [[ -d "${legacy_target}" ]]; then
    legacy_backup_root="${codex_root}/pets/.${legacy_pet_id}-backups"
    legacy_backup_dir="${legacy_backup_root}/${timestamp}-before-${pet_id}"
    mkdir -p "${legacy_backup_root}"
    mv "${legacy_target}" "${legacy_backup_dir}"
    echo "Moved ${legacy_pet_id} to ${legacy_backup_dir}"
  fi
fi

mkdir -p "${target_dir}"
install -m 0644 "${source_dir}/pet.json" "${target_dir}/pet.json"
install -m 0644 "${source_dir}/spritesheet.webp" "${target_dir}/spritesheet.webp"

echo "Installed ${display_name} ${requested_version} to ${target_dir}"
echo "Restart or refresh the desktop app, then select ${display_name}."
