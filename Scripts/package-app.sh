#!/bin/zsh
set -eu
cd "${0:A:h:h}"
bin_dir=${1:-.build/out/Products/Debug}
release_version=$(<VERSION)
app_dir="$PWD/s7r.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/S7RApp" "$app_dir/Contents/MacOS/S7RApp"
for bundle in "$bin_dir"/*.bundle; do
    [[ -e "$bundle" ]] && ditto "$bundle" "$app_dir/Contents/Resources/${bundle:t}"
done
if [[ -e "$bin_dir/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib" ]]; then
    ln -sfn ../Resources/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib "$app_dir/Contents/MacOS/mlx.metallib"
fi
mkdir -p "$app_dir/Contents/Resources/ThirdParty"
cp docs/third-party/* "$app_dir/Contents/Resources/ThirdParty/"
cp LICENSE "$app_dir/Contents/Resources/LICENSE"
cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>kr.s7r.local</string>
<key>CFBundleName</key><string>s7r</string>
<key>CFBundleDisplayName</key><string>s7r</string>
<key>CFBundleExecutable</key><string>S7RApp</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$release_version</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Transcribe selected local media files.</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --deep --sign - --timestamp=none "$app_dir"
codesign --verify --deep --strict "$app_dir"
print "$app_dir"
