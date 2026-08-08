#!/bin/bash
set -euo pipefail
OUT="$HOME/Desktop/Video Screen Saver Generator Diagnostics.txt"
{
  echo "Video Screen Saver Generator diagnostics"
  echo "Date: $(date)"
  echo "macOS: $(sw_vers -productVersion 2>/dev/null || true)"
  echo "Architecture: $(uname -m)"
  echo ""
  echo "Installed savers:"
  ls -lah "$HOME/Library/Screen Savers" 2>&1 || true
  echo ""
  echo "Recent Video Screen Saver Generator / legacyScreenSaver logs:"
  /usr/bin/log show --last 15m --style compact \
    --predicate '(process == "VideoScreenSaverGenerator") OR (process CONTAINS[c] "legacyScreenSaver") OR (subsystem == "local.saverforge.videosaver")' \
    2>&1 || true
} > "$OUT"
open -R "$OUT"
echo "已生成：$OUT"
read -n 1 -s -r -p "按任意键关闭…"
