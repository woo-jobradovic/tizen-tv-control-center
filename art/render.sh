#!/bin/bash
# Renders each art/*.html page to screenshots/<name>.png with headless Chrome.
# Usage: art/render.sh [name...]   (sizes come from the <!-- size WxH --> line, default 1280x640)
cd "$(dirname "$0")"
CHROME="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
pages=("$@"); [ ${#pages[@]} -eq 0 ] && pages=(hero control-center performance debloat)
for p in "${pages[@]}"; do
  size=$(grep -o 'size [0-9]*x[0-9]*' "$p.html" | head -1 | cut -d' ' -f2); size=${size:-1280x640}
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size="${size/x/,}" --screenshot="$(cygpath -w "$PWD/../screenshots/$p.png" 2>/dev/null || echo "$PWD/../screenshots/$p.png")" \
    "file:///$(cygpath -m "$PWD/$p.html" 2>/dev/null || echo "$PWD/$p.html")" >/dev/null 2>&1
  echo "$p -> screenshots/$p.png ($size)"
done
