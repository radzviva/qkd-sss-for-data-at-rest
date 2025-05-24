#!/usr/bin/env bash
set -euo pipefail
set -x

# Pārbauda, vai ffmpeg pieejams
command -v ffmpeg >/dev/null 2>&1 || { echo "❌ ffmpeg nav PATH"; exit 1; }

# Argumenti
INPUT="$1"
BASE="$2"
NUM_SHARES="$3"
TRESHOLDER="$4"
OUTPUT="$5"

# Sanity check
[[ -f "$INPUT" ]] || { echo "❌ Nav ieejas GIF: $INPUT"; exit 1; }

# Teksts
MULTI_TEXT=$'FILE: '"${BASE}"$'\nNUM_SHARES: '"${NUM_SHARES}"$'\nTRESHOLDER: '"${TRESHOLDER}"
ESCAPED_TEXT="${MULTI_TEXT//:/\\:}"

# Filtrs
FILTER="drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:\
text='${ESCAPED_TEXT}':\
fontcolor=white:fontsize=80:box=1:boxcolor=black@0.5:boxborderw=5:\
x=(w-text_w)/2:y=h-text_h-10"

# **Šeit vajag faktisko ffmpeg izsaukumu!**
ffmpeg -y -loglevel error -nostats -i "$INPUT" -vf "$FILTER" -loop 0 "$OUTPUT"

echo "✅ Gif radīts: $OUTPUT"
