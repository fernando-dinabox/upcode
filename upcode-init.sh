#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-init.sh

echo "🚀 UPCODE - Conectando ao servidor..."
echo "📅 $(date '+%H:%M:%S')"

# URL do script principal no servidor
MAIN_SCRIPT_URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh"

# Adicionar timestamp para evitar qualquer cache
TIMESTAMP=$(date +%s%N)
RANDOM_ID=$RANDOM

echo "📡 Baixando script principal do servidor..."

# Executar direto do servidor sem salvar arquivo
curl -s \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "Expires: 0" \
    "${MAIN_SCRIPT_URL}?v=${TIMESTAMP}&r=${RANDOM_ID}&nocache=true" | bash -s -- "$@"

# Se curl falhar
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "❌ Erro ao conectar com o servidor"
    echo "🌐 URL: $MAIN_SCRIPT_URL"
    echo "🔍 Verifique sua conexão com a internet"
    exit 1
fi
