#!/usr/bin/env bash
# MirrorMan Font Downloader (Linux/macOS/WSL)
set -e
DIR="$(cd "$(dirname "$0")" && pwd)/fonts"
mkdir -p "$DIR"

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
dl() {
  local name="$1" url="$2" dest="$DIR/${name}.woff2"
  [[ -f "$dest" ]] && { echo -e "  ${YELLOW}SKIP${RESET} ${name}.woff2"; return; }
  printf "  ${BOLD}GET${RESET}  ${name}.woff2 ... "
  curl -sL --retry 3 -A "Mozilla/5.0" "$url" -o "$dest" && echo -e "${GREEN}OK${RESET}" || echo "FAIL"
}

echo -e "\n🪞 ${BOLD}MirrorMan — Font Downloader${RESET}\n"

# Vazirmatn (Persian UI font)
BASE="https://github.com/rastikerdar/vazirmatn/raw/master/fonts/webfonts"
dl "Vazirmatn-Light"      "$BASE/Vazirmatn-Light.woff2"
dl "Vazirmatn-Regular"    "$BASE/Vazirmatn-Regular.woff2"
dl "Vazirmatn-Medium"     "$BASE/Vazirmatn-Medium.woff2"
dl "Vazirmatn-SemiBold"   "$BASE/Vazirmatn-SemiBold.woff2"
dl "Vazirmatn-Bold"       "$BASE/Vazirmatn-Bold.woff2"
dl "Vazirmatn-ExtraBold"  "$BASE/Vazirmatn-ExtraBold.woff2"

# JetBrains Mono (code blocks)
JBBASE="https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/webfonts"
dl "JetBrainsMono-Regular" "$JBBASE/JetBrainsMono-Regular.woff2"
dl "JetBrainsMono-Medium"  "$JBBASE/JetBrainsMono-Medium.woff2"
dl "JetBrainsMono-Bold"    "$JBBASE/JetBrainsMono-Bold.woff2"

echo -e "\n✅ Done! Open ${BOLD}web/index.html${RESET} in your browser.\n"
