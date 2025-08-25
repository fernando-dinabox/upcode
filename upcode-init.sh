#!/bin/bash
# upcode-init.sh - Sempre executa a versão mais recente

echo "🚀 UPCODE - Executando versão mais recente do servidor..."

# Executar diretamente sem salvar
bash <(curl -s "https://raw.githubusercontent.com/fernando-dinabox/upcode/main/upcode-main.sh?t=$(date +%s%N)")
