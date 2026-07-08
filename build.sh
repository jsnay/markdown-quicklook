#!/bin/zsh
# Build QLMarkdown and install it to /Applications.
# Usage: ./build.sh [TEAM_ID]   (auto-detects your Apple Development team if omitted)
set -euo pipefail
cd "$(dirname "$0")"

# --- Detect development team -------------------------------------------------
TEAM_ID="${1:-${DEVELOPMENT_TEAM:-}}"
if [[ -z "$TEAM_ID" ]]; then
  TEAM_ID=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1)
fi
if [[ -z "$TEAM_ID" ]]; then
  echo "error: no Apple Development certificate found. Pass your team ID: ./build.sh TEAMID1234" >&2
  exit 1
fi
echo "Using development team: $TEAM_ID"

# --- Generate project --------------------------------------------------------
command -v xcodegen >/dev/null || { echo "error: xcodegen not installed (brew install xcodegen)" >&2; exit 1; }
xcodegen generate

# --- Build -------------------------------------------------------------------
xcodebuild \
  -project QLMarkdown.xcodeproj \
  -scheme QLMarkdownApp \
  -configuration Release \
  -derivedDataPath build \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  build

APP="build/Build/Products/Release/QLMarkdownApp.app"
[[ -d "$APP" ]] || { echo "error: build product not found at $APP" >&2; exit 1; }

# --- Install & register ------------------------------------------------------
rm -rf /Applications/QLMarkdownApp.app
ditto "$APP" /Applications/QLMarkdownApp.app
xattr -dr com.apple.quarantine /Applications/QLMarkdownApp.app 2>/dev/null || true
open /Applications/QLMarkdownApp.app
qlmanage -r >/dev/null 2>&1 || true

echo "Installed. Enable (if needed): System Settings → General → Login Items & Extensions → Quick Look"
