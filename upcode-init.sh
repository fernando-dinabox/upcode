#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-init.sh

upcode_init() {
    # Limpar caches do sistema
    hash -r 2>/dev/null
    unset BASH_REMATCH 2>/dev/null
    unset CURRENT_VERSION 2>/dev/null
    
    echo "🚀 UPCODE - Executando direto do servidor"
    echo "📅 $(date '+%H:%M:%S')"
    
    # ID único para garantir bypass de cache
    UNIQUE_ID="$(date +%s%N)_$$_$RANDOM"
    
    echo "🎯 ID: ${UNIQUE_ID:0:15}"
    
    # URL com cache busting
    SCRIPT_URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh"
    FINAL_URL="${SCRIPT_URL}?force=${UNIQUE_ID}&nocache=true&t=$(date +%s)&r=$RANDOM$RANDOM"
    
    echo "📡 Baixando versão mais recente..."
    
    # Executar em subshell com curl compatível com Git Bash
    (
        # Limpar subshell
        hash -r 2>/dev/null
        
        # Download com headers compatíveis (SEM --no-cache)
        curl -sL \
            -H "Cache-Control: no-cache, no-store, must-revalidate" \
            -H "Pragma: no-cache" \
            -H "Expires: 0" \
            -H "User-Agent: UPCODE-${UNIQUE_ID}" \
            "$FINAL_URL" | bash -s -- "$@"
    )
    
    # Limpar após execução  
    hash -r 2>/dev/null
    unset CURRENT_VERSION 2>/dev/null
}

upcode_init "$@"
