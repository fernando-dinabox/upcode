#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-init.sh

echo "🚀 UPCODE - Executando direto do servidor"
echo "📅 $(date '+%H:%M:%S')"

# Executar direto sem salvar arquivo
curl -s "https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh?nocache=$(date +%s)" | bash -s -- "$@"
