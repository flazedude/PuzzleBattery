#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
if [[ "$configuration" != "release" && "$configuration" != "debug" ]]; then
    echo "Usage: $0 [release|debug]" >&2
    exit 1
fi
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app="build/PuzzleBattery.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/AppIcon.iconset
cp "$bin_dir/PuzzleBattery" "$app/Contents/MacOS/PuzzleBattery"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [[ ! -f build/AppIcon.png || scripts/make-icon.swift -nt build/AppIcon.png ]]; then
    swift scripts/make-icon.swift build/AppIcon.png
fi
for point_size in 16 32 128 256 512; do
    sips -z "$point_size" "$point_size" build/AppIcon.png --out "build/AppIcon.iconset/icon_${point_size}x${point_size}.png" >/dev/null
    double_size=$((point_size * 2))
    sips -z "$double_size" "$double_size" build/AppIcon.png --out "build/AppIcon.iconset/icon_${point_size}x${point_size}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$app"
echo "Built $PWD/$app"
