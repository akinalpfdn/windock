#!/bin/bash
# Updates appcast.xml with a new release entry for Sparkle auto-updates.
# Usage: ./scripts/update-appcast.sh <version> <dmg-path>
# Example: ./scripts/update-appcast.sh 1.5.0 /tmp/WinDock.dmg

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

# Get file size and EdDSA signature
FILE_SIZE=$(stat -f%z "$DMG_PATH")
SIGNATURE=$("$SIGN_UPDATE" "$DMG_PATH" 2>&1 | grep 'edSignature=' | sed 's/.*edSignature="\([^"]*\)".*/\1/')

if [ -z "$SIGNATURE" ]; then
    # Fallback: full output contains just the signature attributes
    SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH" 2>&1)
    SIGNATURE=$(echo "$SIGN_OUTPUT" | head -1)
fi

DOWNLOAD_URL="https://github.com/akinalpfdn/windock/releases/download/v${VERSION}/WinDock.dmg"
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")

# Get the signature output directly (Sparkle outputs sparkle:edSignature="..." length="...")
SPARKLE_ATTRS=$("$SIGN_UPDATE" "$DMG_PATH" 2>&1)

# Build the new item entry
NEW_ITEM="    <item>
      <title>WinDock ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure
        url=\"${DOWNLOAD_URL}\"
        ${SPARKLE_ATTRS}
        type=\"application/octet-stream\"
        sparkle:version=\"${VERSION}\"
        sparkle:shortVersionString=\"${VERSION}\"
      />
    </item>"

# Insert before closing </channel> tag
if grep -q "<item>" "$APPCAST"; then
    # Has existing items - add before </channel>
    sed -i '' "s|  </channel>|${NEW_ITEM}\n  </channel>|" "$APPCAST"
else
    # No items yet - add after <language> line
    sed -i '' "s|    <language>en</language>|    <language>en</language>\n${NEW_ITEM}|" "$APPCAST"
fi

echo "✅ Appcast updated: v${VERSION} (${FILE_SIZE} bytes)"
