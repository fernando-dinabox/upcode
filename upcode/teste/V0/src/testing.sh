

test_path_formats() {
    clear_screen
    echo "🧪 TESTE DE FORMATOS DE CAMINHO"
    echo "═══════════════════════════════"
    
    # Array com diferentes formatos para teste - mantendo apenas o formato desejado
    local test_paths=(
        "fernando-teste\/Pasta completa"  # Formato desejado com \/ 
    )
    
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        echo "❌ Token não encontrado"
        pause
        return
    fi
    
    echo "🔍 Testando formato com barra invertida + barra normal..."
    echo
    
    for path in "${test_paths[@]}"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📝 Testando path: '$path'"
        
        # Mostrar exatamente como está
        printf "🔸 Original (raw):    '%s'\n" "$path"
        
        # Enviar requisição preservando o formato exato
        echo
        echo "📡 Enviando requisição..."
        
        # Usar printf para preservar os caracteres de escape
        local escaped_path=$(printf '%s' "$path")
        
        # Debug do comando curl antes de executar
        echo "🔧 DEBUG - Comando curl que será executado:"
        echo "curl -s -X POST \"$CONFIG_URL\" -H \"Authorization: Bearer ...\" --data-raw \"action=list\" --data-raw \"path=$escaped_path\""
        
        # Fazer a requisição preservando exatamente o formato
        local response=$(curl -s -X POST "$CONFIG_URL" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            --data-urlencode "action=list" \
            --data-raw "path=$escaped_path")
        
        echo
        echo "📥 RESPOSTA:"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        
        # Extrair e mostrar os paths
        local server_path=$(echo "$response" | jq -r '.data.path // ""' 2>/dev/null)
        local server_normalized=$(echo "$response" | jq -r '.data.normalized_path // ""' 2>/dev/null)
        
        echo
        echo "🔍 ANÁLISE DETALHADA:"
        echo "  Formato desejado: 'fernando-teste\/Pasta completa'"
        echo "  Path enviado:     '$escaped_path'"
        echo "  Path recebido:    '$server_path'"
        echo "  Path normalizado: '$server_normalized'"
        echo
        
        if [[ "$server_path" == "fernando-teste\/Pasta completa" ]]; then
            echo "✅ SUCESSO: O path foi recebido no formato correto!"
        else
            echo "❌ ERRO: O path não está no formato desejado"
        fi
        echo
        
        if confirm "Continuar com próximo teste?"; then
            continue
        else
            break
        fi
    done
    
    pause
}