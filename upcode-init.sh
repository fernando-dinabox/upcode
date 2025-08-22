#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-init.sh

CACHE_FILE="$HOME/.upcode_cached.sh"
SERVER_URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh"

# Função de limpeza
cleanup() {
    rm -f "$CACHE_FILE"
}

# Configurar trap para limpar o cache ao sair
trap cleanup EXIT

echo "🔄 Baixando versão mais recente..."

# SEMPRE remover cache e baixar novo
rm -f "$CACHE_FILE"

# Baixar e executar
if curl -s "$SERVER_URL" -o "$CACHE_FILE" && [[ -s "$CACHE_FILE" ]]; then
    chmod +x "$CACHE_FILE"
    echo "✅ Executando versão mais recente..."
    exec bash "$CACHE_FILE" "$@"
else
    echo "❌ Falha ao baixar script do servidor"
    exit 1
fi
