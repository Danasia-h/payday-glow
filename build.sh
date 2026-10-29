#!/bin/zsh
set -eu
cd "$(dirname "$0")"
APP="${1:-build/薪动.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/module-cache
swiftc -O -target arm64-apple-macosx13.0 -module-cache-path build/module-cache Sources/*.swift -o "$APP/Contents/MacOS/SalaryClock" -framework AppKit -framework SwiftUI -framework CoreGraphics
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SalaryClock</string>
<key>CFBundleIdentifier</key><string>local.xindong.salaryclock</string>
<key>CFBundleName</key><string>薪动</string>
<key>CFBundleDisplayName</key><string>薪动</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundleShortVersionString</key><string>1.1.1</string>
<key>LSUIElement</key><true/>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSSupportsAutomaticTermination</key><false/>
</dict></plist>
PLIST
if [ -f Assets/AppIcon.icns ]; then cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"; fi
codesign --force --sign - "$APP"
echo "已生成：$APP"
