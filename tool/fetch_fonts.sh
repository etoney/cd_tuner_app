#!/usr/bin/env bash
# Bundles the app's fonts so it looks right on first launch, even offline.
# Downloads static TTFs from Google Fonts (all SIL Open Font License) into
# assets/google_fonts/, named the way the google_fonts package looks for them.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=assets/google_fonts
mkdir -p "$OUT"
fetch() { # family-for-url weight file-name
  local css url
  css=$(curl -fsSL "https://fonts.googleapis.com/css2?family=$1:wght@$2")
  url=$(printf '%s' "$css" | grep -o 'https://[^)]*' | head -1)
  curl -fsSL "$url" -o "$OUT/$3.ttf"
  echo "bundled $3.ttf"
}
fetch Cinzel 700 Cinzel-Bold
fetch Grenze+Gotisch 700 GrenzeGotisch-Bold
fetch Anton 400 Anton-Regular
fetch UnifrakturCook 700 UnifrakturCook-Bold
