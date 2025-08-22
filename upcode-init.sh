#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-init.sh

SERVER_URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh"
TEMP_FILE="/tmp/upcode_$(date +%s).sh"

echo "🔄 Baixando versão do servidor..."
curl -s "$SERVER_URL" -o "$TEMP_FILE"

echo "✅ Executando..."
chmod +x "$TEMP_FILE"
bash "$TEMP_FILE" "$@"

# Limpar
rm -f "$TEMP_FILE"
