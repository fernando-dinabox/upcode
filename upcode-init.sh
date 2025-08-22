#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-init.sh

# FORÇAR LIMPEZA TOTAL A CADA EXECUÇÃO
echo "🔥 UPCODE - FORÇANDO VERSÃO FRESCA"
echo "📅 $(date '+%H:%M:%S')"

# Limpar TUDO que pode estar em cache
unset -f upcode_init 2>/dev/null
unset CURRENT_VERSION 2>/dev/null  
hash -r 2>/dev/null
unset BASH_REMATCH 2>/dev/null

# ID único para garantir que não há cache
UNIQUE_ID="$(date +%s%N)_$$_$RANDOM_$(whoami)"

echo "🎯 ID da sessão: ${UNIQUE_ID:0:20}"

# URL com cache busting extremo  
SCRIPT_URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh"
FINAL_URL="${SCRIPT_URL}?force=${UNIQUE_ID}&nocache=true&t=$(date +%s)&r=$RANDOM$RANDOM&bust=force"

echo "📡 Baixando sempre versão mais recente..."

# Executar em subshell completamente isolado
(
    # Limpar tudo no subshell
    unset -f $(compgen -A function 2>/dev/null) 2>/dev/null || true
    hash -r 2>/dev/null
    
    # Download com headers anti-cache máximos
    curl -sL \
        --max-time 30 \
        --no-cache \
        --no-sessionid \
        -H "Cache-Control: no-cache, no-store, must-revalidate, max-age=0" \
        -H "Pragma: no-cache" \
        -H "Expires: 0" \
        -H "If-Modified-Since: Thu, 01 Jan 1970 00:00:00 GMT" \
        -H "User-Agent: UPCODE-FORCE-${UNIQUE_ID}" \
        "$FINAL_URL" | bash -s -- "$@"
)

# Limpar após execução
unset -f upcode_init 2>/dev/null
hash -r 2>/dev/null

echo "🧹 Sessão limpa"
