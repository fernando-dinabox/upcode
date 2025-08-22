#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-init.sh

echo "🚀 UPCODE - FORÇA TOTAL ANTI-CACHE"
echo "📅 $(date '+%H:%M:%S')"

# Combinar todos os métodos anti-cache
TIMESTAMP=$(date +%s%N)
RANDOM1=$RANDOM
RANDOM2=$RANDOM
URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh"

# Múltiplos cache busters
FINAL_URL="${URL}?v=${TIMESTAMP}&r1=${RANDOM1}&r2=${RANDOM2}&nocache=true&bust=force"

echo "🔄 URL: ...upcode-fixed.sh?v=${TIMESTAMP}..."

curl -s \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "Expires: 0" \
    -H "User-Agent: UPCODE-Fetcher-${TIMESTAMP}" \
    "$FINAL_URL" | bash -s -- "$@"
