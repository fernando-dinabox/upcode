#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-init.sh

SERVER_URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh"
TEMP_FILE="/tmp/upcode_$(date +%s%N).sh"

echo "🔄 Baixando versão mais recente do servidor..."

# SEMPRE baixar para arquivo temporário único (sem cache)
if curl -s "$SERVER_URL" -o "$TEMP_FILE" 2>/dev/null && [[ -s "$TEMP_FILE" ]]; then
    echo "✅ Executando versão do servidor..."
    chmod +x "$TEMP_FILE"
    
    # Executar e limpar
    bash "$TEMP_FILE" "$@"
    rm -f "$TEMP_FILE"
else
    echo "❌ Falha ao baixar do servidor: $SERVER_URL"
    echo "🔍 Verifique conexão e se o repositório está público"
    rm -f "$TEMP_FILE" 2>/dev/null
    exit 1
fi
