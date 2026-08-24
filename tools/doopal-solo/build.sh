#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${script_dir}/build"
binary_path="${build_dir}/doopal-solo"
app_dir="${build_dir}/Doopal.app"

if ! command -v swiftc >/dev/null; then
  echo "swiftc not found. Install the Xcode command line tools with: xcode-select --install" >&2
  exit 1
fi

mkdir -p "${build_dir}"
swiftc -O "${script_dir}/DoopalSolo.swift" -o "${binary_path}"

rm -rf "${app_dir}"
mkdir -p "${app_dir}/Contents/MacOS" "${app_dir}/Contents/Resources"
cp "${binary_path}" "${app_dir}/Contents/MacOS/doopal-solo"

cat > "${app_dir}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Doopal</string>
  <key>CFBundleDisplayName</key><string>Doopal</string>
  <key>CFBundleIdentifier</key><string>com.kwakdoo8.doopal-solo</string>
  <key>CFBundleExecutable</key><string>doopal-solo</string>
  <key>CFBundleIconFile</key><string>Doopal</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

iconset_dir="${build_dir}/Doopal.iconset"
rm -rf "${iconset_dir}"
if "${binary_path}" --dump-icon "${iconset_dir}" >/dev/null 2>&1; then
  iconutil -c icns "${iconset_dir}" -o "${app_dir}/Contents/Resources/Doopal.icns"
  rm -rf "${iconset_dir}"
else
  echo "No spritesheet found, so the app was built without an icon" >&2
fi

codesign --force --sign - "${app_dir}" >/dev/null 2>&1 || true
touch "${app_dir}"

echo "Built ${binary_path}"
echo "Built ${app_dir}"
