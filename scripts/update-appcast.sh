#!/bin/bash
# Updates appcast.xml with a new release entry for Sparkle auto-updates.
# Usage: ./scripts/update-appcast.sh <version> <dmg-path>

set -euo pipefail

VERSION="$1"
DMG_PATH="$2"
APPCAST="appcast.xml"
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f 2>/dev/null | head -1)

if [ -z "$SIGN_UPDATE" ]; then
    echo "Error: sign_update tool not found. Build the project in Xcode first."
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    exit 1
fi

SPARKLE_ATTRS=$("$SIGN_UPDATE" "$DMG_PATH" 2>&1)
DOWNLOAD_URL="https://github.com/akinalpfdn/windock/releases/download/v${VERSION}/WinDock.dmg"
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
FILE_SIZE=$(stat -f%z "$DMG_PATH")

python3 - "$APPCAST" "$VERSION" "$PUB_DATE" "$DOWNLOAD_URL" "$SPARKLE_ATTRS" "$FILE_SIZE" << 'PYEOF'
import sys

appcast_path, version, pub_date, url, sparkle_attrs, file_size = sys.argv[1:7]

item = f"""    <item>
      <title>WinDock {version}</title>
      <pubDate>{pub_date}</pubDate>
      <enclosure
        url="{url}"
        {sparkle_attrs}
        type="application/octet-stream"
        sparkle:version="{version}"
        sparkle:shortVersionString="{version}"
      />
    </item>"""

with open(appcast_path, 'r') as f:
    content = f.read()

content = content.replace('  </channel>', item + '\n  </channel>')

with open(appcast_path, 'w') as f:
    f.write(content)

print(f"✅ Appcast updated: v{version} ({file_size} bytes)")
PYEOF
