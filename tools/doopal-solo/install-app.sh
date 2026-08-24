#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="${script_dir}/build/Doopal.app"
target_root="${HOME}/Applications"
target_dir="${target_root}/Doopal.app"

"${script_dir}/build.sh"

mkdir -p "${target_root}"
if [[ -d "${target_dir}" ]]; then
  rm -rf "${target_dir}"
  echo "Replaced the app at ${target_dir}"
fi

cp -R "${app_dir}" "${target_dir}"
touch "${target_dir}"

echo "Installed Doopal to ${target_dir}"
if pgrep -f "Doopal.app/Contents/MacOS/doopal-solo" >/dev/null; then
  echo "Doopal is already running. Quit and start it again to use this build."
fi
echo "Start it from Spotlight, or run: open -a ${target_dir}"
echo "Stop it by right-clicking the Pet, then Quit Doopal."
