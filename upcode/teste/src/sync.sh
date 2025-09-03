# Iniciar sincronização da pasta local com o servidor
start_server_sync_with_local_path() {
    local local_folder="$1"
    local server_path="$2"
    
    clear_screen
    echo "🔄 CONFIGURAÇÃO DE SINCRONIZAÇÃO"
    echo "==============================="
    echo "📂 Pasta local: $(basename "$local_folder")"
    echo "🌐 Pasta servidor: $server_path"
    echo
    
    # Contar arquivos locais
    local local_count=$(find "$local_folder" -type f 2>/dev/null | wc -l)
    echo "📊 Arquivos locais encontrados: $local_count"
    
    if [[ $local_count -eq 0 ]]; then
        echo "⚠️ Nenhum arquivo encontrado na pasta local"
        pause
        return
    fi
    
    # Fazer comparação inteligente
    echo "🔍 Fazendo análise inicial..."
    smart_folder_comparison "$local_folder" "$server_path"
    
    echo
    read -p "⏱️ Intervalo de verificação (segundos, padrão 3): " interval </dev/tty
    interval=${interval:-3}
    
    if confirm "🚀 Iniciar monitoramento contínuo?"; then
        # O caminho final estará salvo em /tmp/upcode_final_path
        local final_destination="$server_path"
        if [[ -f "/tmp/upcode_final_path" ]]; then
            final_destination=$(cat "/tmp/upcode_final_path")
        fi
        
        start_silent_monitoring "$local_folder" "$final_destination" "$interval"
    else
        echo "❌ Sincronização cancelada"
    fi
    
    pause
}


# Log para sincronização
sync_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$SYNC_LOG_FILE"
    
    # Manter últimas 50 linhas do log
    if [[ -f "$SYNC_LOG_FILE" ]]; then
        tail -n 50 "$SYNC_LOG_FILE" > "$SYNC_LOG_FILE.tmp"
        mv "$SYNC_LOG_FILE.tmp" "$SYNC_LOG_FILE"
    fi
}

# Normalizar caminhos para upload
normalize_sync_path() {
    local path="$1"
    path="${path//\\/\/}"  # Remove escapes
    while [[ "$path" =~ // ]]; do
        path="${path//\/\//\/}"  # Remove barras duplas
    done
    path="${path#/}"  # Remove barra inicial
    path="${path%/}"  # Remove barra final
    echo "$path"
}

# Upload de arquivo para sincronização
perform_sync_upload() {
    local file="$1"
    local destination="$2"
    local rel_path="$3"
    local with_delete="$4"
    
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]] || [[ ! -f "$file" ]]; then
        sync_log "❌ Erro: Token não encontrado ou arquivo inválido ($file)"
        return 1
    fi
    
    # Corrigir caminho para Windows
    local corrected_file="$file"
    if [[ "$file" =~ ^/c/ ]]; then
        corrected_file=$(echo "$file" | sed 's|^/c|C:|')
    elif [[ "$file" =~ ^[a-zA-Z]:\\ ]]; then
        corrected_file=$(echo "$file" | sed 's|\\|/|g')
    fi
    
    # Construir comando curl
    local curl_cmd=(
        curl -s -X POST "$CONFIG_URL"
        -H "Authorization: Bearer $token"
        -F "arquivo[]=@$corrected_file"
        -F "pasta=$destination"
        --max-time 30
    )
    
    if [[ -n "$rel_path" && "$rel_path" != "." ]]; then
        curl_cmd+=(-F "path=$rel_path")
    fi
    
    if [[ "$with_delete" == "true" ]]; then
        curl_cmd+=(-F "with_delete=true")
    fi
    
    sync_log "🔄 Enviando: $(basename "$file") -> $destination/$rel_path"
    
    local response=$("${curl_cmd[@]}" 2>/dev/null)
    local curl_exit=$?
    
    if [[ $curl_exit -ne 0 ]]; then
        sync_log "❌ CURL ERROR: Code $curl_exit para $(basename "$file")"
        return 1
    fi
    
    if echo "$response" | grep -q '"success":[[:space:]]*true'; then
        sync_log "✅ SUCESSO: $(basename "$file")"
        return 0
    else
        local message=$(echo "$response" | grep -o '"message":[[:space:]]*"[^"]*"' | sed 's/.*"message":[[:space:]]*"\([^"]*\)".*/\1/' || echo "Erro desconhecido")
        sync_log "❌ FALHA: $(basename "$file") - $message"
        return 1
    fi
}

# Verificar mudanças e sincronizar
sync_check_and_upload() {
    local local_folder="$1"
    local destination="$2" 
    local with_delete="$3"
    
    if [[ ! -d "$local_folder" ]]; then
        sync_log "❌ Pasta local não encontrada: $local_folder"
        return 1
    fi
    
    # Inicializar cache se não existir
    if [[ ! -f "$SYNC_CACHE_FILE" ]]; then
        touch "$SYNC_CACHE_FILE"
    fi
    
    # Estado atual dos arquivos
    local current_cache=$(find "$local_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort)
    local old_cache=$(cat "$SYNC_CACHE_FILE" 2>/dev/null || echo "")
    
    local files_to_sync=()
    
    # Detectar arquivos novos/modificados
    while IFS='|' read -r file_path timestamp size; do
        [[ -z "$file_path" ]] && continue
        
        local old_entry=$(echo "$old_cache" | grep -F "$file_path|")
        if [[ -z "$old_entry" ]]; then
            files_to_sync+=("$file_path")
            sync_log "🆕 NOVO: $(basename "$file_path")"
        else
            local old_timestamp=$(echo "$old_entry" | cut -d'|' -f2)
            if [[ "$timestamp" != "$old_timestamp" ]]; then
                files_to_sync+=("$file_path")
                sync_log "✏️ MODIFICADO: $(basename "$file_path")"
            fi
        fi
    done <<< "$current_cache"
    
    if [[ ${#files_to_sync[@]} -eq 0 ]]; then
        # Atualizar cache mesmo sem sincronização
        echo "$current_cache" > "$SYNC_CACHE_FILE"
        return 0  # Nenhuma mudança
    fi
    
    sync_log "📊 Sincronizando ${#files_to_sync[@]} arquivo(s)"
    
    local sync_success=0
    local sync_failed=0
    local delete_applied=false
    
    for file in "${files_to_sync[@]}"; do
        local size=$(stat -c %s "$file" 2>/dev/null)
        if [[ $size -gt 10485760 ]]; then  # 10MB
            sync_log "❌ Arquivo muito grande: $(basename "$file") ($size bytes)"
            ((sync_failed++))
            continue
        fi
        
        local rel_path="${file#$local_folder/}"
        rel_path=$(normalize_sync_path "$rel_path")
        
        local current_with_delete="false"
        if [[ "$with_delete" == "true" && "$delete_applied" == "false" ]]; then
            current_with_delete="true"
            delete_applied=true
            sync_log "🗑️ Aplicando exclusão prévia"
        fi
        
        if perform_sync_upload "$file" "$destination" "$rel_path" "$current_with_delete"; then
            ((sync_success++))
        else
            ((sync_failed++))
        fi
        
        sleep 0.2
    done
    
    # Atualizar cache
    echo "$current_cache" > "$SYNC_CACHE_FILE"
    
    if [[ $sync_success -gt 0 || $sync_failed -gt 0 ]]; then
        sync_log "✅ RESULTADO: $sync_success sucessos, $sync_failed falhas"
        return $sync_success  # Retorna número de sucessos
    fi
    
    return 0
}

# Monitoramento silencioso
start_silent_monitoring() {
    local local_folder="$1"
    local destination="$2"
    local interval="$3"
    
    # Usar caminho final se existir
    if [[ -f "/tmp/upcode_final_path" ]]; then
        destination=$(cat "/tmp/upcode_final_path")
        rm -f "/tmp/upcode_final_path"
    fi
    
    # Limpar log anterior
    > "$SYNC_LOG_FILE"
    
    # Inicializar cache
    find "$local_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort > "$SYNC_CACHE_FILE"
    
    clear
    echo "🔄 SINCRONIZAÇÃO CONTÍNUA ATIVA"
    echo "═══════════════════════════════"
    echo "📁 Pasta local: $(basename "$local_folder")"
    echo "🌐 Destino: $destination"
    echo "⏱️ Intervalo: ${interval}s"
    echo "📜 Log: $SYNC_LOG_FILE"
    echo
    echo "💡 Monitorando mudanças..."
    echo "ℹ️  Exibindo apenas quando houver alterações"
    echo
    echo "⏹️ Pressione Ctrl+C para parar"
    echo
    
    # Trap para sair
    trap 'echo -e "\n⏹️ Sincronização interrompida"; return 0' INT
    
    while true; do
        silent_sync_check "$local_folder" "$destination"
        sleep "$interval"
    done
}



# Verificação silenciosa
silent_sync_check() {
    local local_folder="$1"
    local destination="$2"
    
    if [[ ! -d "$local_folder" ]]; then
        return 1
    fi
    
    # Inicializar cache se não existir
    if [[ ! -f "$SYNC_CACHE_FILE" ]]; then
        touch "$SYNC_CACHE_FILE"
    fi
    
    local current_cache=$(find "$local_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort)
    local old_cache=$(cat "$SYNC_CACHE_FILE" 2>/dev/null || echo "")
    
    local files_to_sync=()
    
    # Detectar mudanças
    while IFS='|' read -r file_path timestamp size; do
        [[ -z "$file_path" ]] && continue
        
        local old_entry=$(echo "$old_cache" | grep -F "$file_path|")
        if [[ -z "$old_entry" ]]; then
            files_to_sync+=("$file_path")
            echo "[$(date '+%H:%M:%S')] 🆕 NOVO: $(basename "$file_path")"
        else
            local old_timestamp=$(echo "$old_entry" | cut -d'|' -f2)
            if [[ "$timestamp" != "$old_timestamp" ]]; then
                files_to_sync+=("$file_path")
                echo "[$(date '+%H:%M:%S')] ✏️ MODIFICADO: $(basename "$file_path")"
            fi
        fi
    done <<< "$current_cache"
    
    # Se não há mudanças, atualizar cache silenciosamente
    if [[ ${#files_to_sync[@]} -eq 0 ]]; then
        echo "$current_cache" > "$SYNC_CACHE_FILE"
        return 0
    fi
    
    echo "[$(date '+%H:%M:%S')] 📊 Sincronizando ${#files_to_sync[@]} arquivo(s)"
    
    # Processar uploads
    local sync_success=0
    local delete_applied=false
    
    for file in "${files_to_sync[@]}"; do
        local size=$(stat -c %s "$file" 2>/dev/null)
        if [[ $size -gt 10485760 ]]; then  # 10MB
            continue
        fi
        
        local rel_path="${file#$local_folder/}"
        rel_path=$(normalize_sync_path "$rel_path")
        
        local current_with_delete="false"
        if [[ "$delete_applied" == "false" ]]; then
            delete_applied=true
        fi
        
        if perform_sync_upload "$file" "$destination" "$rel_path" "$current_with_delete"; then
            ((sync_success++))
            echo "[$(date '+%H:%M:%S')] ✅ $(basename "$file")"
        else
            echo "[$(date '+%H:%M:%S')] ❌ $(basename "$file")"
        fi
        
        sleep 0.2
    done
    
    # Atualizar cache
    echo "$current_cache" > "$SYNC_CACHE_FILE"
    
    if [[ $sync_success -gt 0 ]]; then
        echo "[$(date '+%H:%M:%S')] ✅ $sync_success arquivo(s) sincronizado(s)"
    fi
}

# Configurar sincronização para uma pasta
start_folder_sync() {
    local local_folder="$1"
    
    if [[ ! -d "$local_folder" ]]; then
        echo "❌ Pasta não encontrada: $local_folder"
        pause
        return
    fi
    
    # Garantir login válido
    ensure_valid_login
    
    clear_screen
    echo "🔄 CONFIGURAR SINCRONIZAÇÃO"
    echo "══════════════════════════"
    echo "📁 Pasta local: $(basename "$local_folder")"
    echo "📂 Caminho: $local_folder"
    echo
    
    # Contar arquivos
    local file_count=$(find "$local_folder" -type f 2>/dev/null | wc -l)
    echo "📊 Arquivos encontrados: $file_count"
    
    if [[ $file_count -eq 0 ]]; then
        echo "⚠️ Nenhum arquivo encontrado na pasta"
        pause
        return
    fi
    
    echo
    echo "📁 Selecione a pasta de destino no servidor:"
    
    # Selecionar pasta de destino
    local destination=$(printf '%s\n' "${user_folders[@]}" | \
        fzf --prompt="Destino servidor > " \
            --header="Onde sincronizar os arquivos" \
            --height=$((${#user_folders[@]} + 5)))
    
    if [[ -z "$destination" ]]; then
        echo "❌ Operação cancelada"
        pause
        return
    fi
    
    echo
    echo "📋 CONFIGURAÇÃO:"
    echo "   📂 Local: $(basename "$local_folder") ($file_count arquivos)"
    echo "   🌐 Servidor: $destination"
    echo
    
    # Fazer comparação inicial
    echo "🔍 Fazendo comparação inicial..."
    local changes=$(sync_check_and_upload "$local_folder" "$destination" "false")
    
    echo
    read -p "⏱️ Intervalo de verificação (segundos, padrão 3): " interval
    interval=${interval:-3}
    
    if confirm "🚀 Iniciar monitoramento contínuo?"; then
        start_sync_monitoring "$local_folder" "$destination" "$interval"
    else
        echo "❌ Sincronização cancelada"
    fi
    
    pause
}

start_server_sync() {
    local server_path="$1"
    
    if [[ -z "$server_path" ]]; then
        echo "❌ Caminho do servidor não especificado"
        pause
        return
    fi
    
    clear_screen
    echo "🔄 CONFIGURAR SINCRONIZAÇÃO COM SERVIDOR"
    echo "========================================"
    echo "🌐 Pasta no servidor: $server_path"
    echo
    
    # Pedir pasta local
    echo "📁 Digite o caminho da pasta LOCAL para sincronizar:"
    local local_folder=""
    while [[ -z "$local_folder" ]]; do
        read -p "📂 Caminho: " local_folder </dev/tty
        
        if [[ ! -d "$local_folder" ]]; then
            echo "❌ Pasta não encontrada: $local_folder"
            local_folder=""
            if confirm "Tentar novamente?"; then
                continue
            else
                return
            fi
        fi
    done
    
    # Chamar função principal
    start_server_sync_with_local_path "$local_folder" "$server_path"
}

# Comparar arquivos local vs servidor
compare_local_vs_server() {
    local local_folder="$1"
    local server_path="$2"
    
    # Obter lista de arquivos locais
    local local_files=()
    while IFS= read -r -d '' file; do
        local rel_path="${file#$local_folder/}"
        local_files+=("$rel_path")
    done < <(find "$local_folder" -type f -print0 2>/dev/null)
    
    # Obter lista de arquivos do servidor
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        echo "❌ Token não encontrado"
        return 1
    fi
    
    # Normalizar caminho do servidor
    local clean_server_path=$(normalize_path "$server_path")
    
    # Fazer requisição para obter arquivos do servidor
    local response=$(curl -s -X POST "$CONFIG_URL" \
        -H "Authorization: Bearer $token" \
        -d "action=list" \
        -d "path=$clean_server_path")
    
    local server_files=()
    if echo "$response" | grep -q '"success":[[:space:]]*true'; then
        # Extrair nomes dos arquivos do servidor
        while IFS= read -r line; do
            if [[ "$line" =~ \"name\":[[:space:]]*\"([^\"]+)\" ]]; then
                local file_name="${BASH_REMATCH[1]}"
                # Verificar se é arquivo (não diretório)
                if ! echo "$response" | grep -A3 -B3 "\"name\":[[:space:]]*\"$file_name\"" | grep -q '"type":[[:space:]]*"directory"'; then
                    server_files+=("$file_name")
                fi
            fi
        done <<< "$response"
    fi
    
    echo
    echo "📊 RESULTADO DA COMPARAÇÃO:"
    echo "═══════════════════════════"
    echo "📂 Arquivos locais: ${#local_files[@]}"
    echo "🌐 Arquivos servidor: ${#server_files[@]}"
    echo
    
    # Encontrar arquivos apenas locais (serão enviados)
    local only_local=()
    for local_file in "${local_files[@]}"; do
        local found=false
        for server_file in "${server_files[@]}"; do
            if [[ "$local_file" == "$server_file" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            only_local+=("$local_file")
        fi
    done
    
    # Encontrar arquivos apenas no servidor
    local only_server=()
    for server_file in "${server_files[@]}"; do
        local found=false
        for local_file in "${local_files[@]}"; do
            if [[ "$server_file" == "$local_file" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            only_server+=("$server_file")
        fi
    done
    
    # Exibir diferenças
    if [[ ${#only_local[@]} -gt 0 ]]; then
        echo "🆕 ARQUIVOS NOVOS (serão enviados): ${#only_local[@]}"
        printf '   📤 %s\n' "${only_local[@]}" | head -10
        if [[ ${#only_local[@]} -gt 10 ]]; then
            echo "   📤 ... e mais $((${#only_local[@]} - 10)) arquivos"
        fi
        echo
    fi
    
    if [[ ${#only_server[@]} -gt 0 ]]; then
        echo "⚠️ ARQUIVOS NO SERVIDOR: ${#only_server[@]}"
        printf '   🌐 %s\n' "${only_server[@]}" | head -10
        if [[ ${#only_server[@]} -gt 10 ]]; then
            echo "   🌐 ... e mais $((${#only_server[@]} - 10)) arquivos"
        fi
        echo
    fi
    
    if [[ ${#only_local[@]} -eq 0 && ${#only_server[@]} -eq 0 ]]; then
        echo "✅ PASTAS SINCRONIZADAS - Mesmo conteúdo"
    fi
}




# Comparação inteligente considerando estrutura de pastas
smart_folder_comparison() {
    local local_folder="$1"
    local server_path="$2"
    
    # Nome da pasta local
    local local_folder_name=$(basename "$local_folder")
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        echo "❌ Token não encontrado"
        return 1
    fi
    
    echo "🔍 ANÁLISE INTELIGENTE DE ESTRUTURA"
    echo "═══════════════════════════════════"
    echo "📂 Pasta local: '$local_folder_name'"
    echo "🌐 Verificando servidor em: '$server_path'"
    echo
    
    # Verificar se server_path já contém subpasta
    local final_server_path="$server_path"
    local create_subfolder=false
    
    # Se server_path termina com mesmo nome da pasta local, usar como está
    if [[ "$server_path" == *"/$local_folder_name" ]]; then
        echo "✅ Caminho servidor já aponta para subpasta: '$local_folder_name'"
        final_server_path="$server_path"
    else
        # Verificar se subpasta existe no servidor
        local clean_server_path=$(normalize_path "$server_path")
        local response=$(curl -s -X POST "$CONFIG_URL" \
            -H "Authorization: Bearer $token" \
            -d "action=list" \
            -d "path=$clean_server_path")
        
        local has_subfolder=false
        if echo "$response" | grep -q '"success":[[:space:]]*true'; then
            # Procurar pela pasta com mesmo nome
            while IFS= read -r line; do
                if [[ "$line" =~ \"name\":[[:space:]]*\"([^\"]+)\" ]]; then
                    local item_name="${BASH_REMATCH[1]}"
                    if echo "$response" | grep -A3 -B3 "\"name\":[[:space:]]*\"$item_name\"" | grep -q '"type":[[:space:]]*"directory"'; then
                        if [[ "$item_name" == "$local_folder_name" ]]; then
                            has_subfolder=true
                            break
                        fi
                    fi
                fi
            done <<< "$response"
        fi
        
        if [[ "$has_subfolder" == "true" ]]; then
            echo "✅ Pasta '$local_folder_name' JÁ EXISTE no servidor"
            final_server_path="$server_path/$local_folder_name"
        else
            echo "📂 Pasta '$local_folder_name' NÃO EXISTE no servidor"
            echo "💡 Escolha o destino:"
            echo "  1️⃣  Enviar para raiz de '$server_path'"
            echo "  2️⃣  Criar pasta '$local_folder_name' no servidor"
            
            read -p "Escolha (1 ou 2): " choice </dev/tty
            if [[ "$choice" == "2" ]]; then
                final_server_path="$server_path/$local_folder_name"
                create_subfolder=true
            fi
        fi
    fi
    
    echo "🎯 Destino final: $final_server_path"
    
    # Fazer comparação com destino final
    detailed_folder_comparison "$local_folder" "$final_server_path"
    
    # Salvar caminho final para uso posterior
    echo "$final_server_path" > "/tmp/upcode_final_path"
}

# Comparação detalhada
detailed_folder_comparison() {
    local local_folder="$1"
    local server_path="$2"
    
    # Obter arquivos locais
    local local_files=()
    while IFS= read -r -d '' file; do
        local rel_path="${file#$local_folder/}"
        local_files+=("$rel_path")
    done < <(find "$local_folder" -type f -print0 2>/dev/null)
    
    # Obter arquivos do servidor
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    local server_files=()
    
    #  Usar o server_path EXATO como veio das pastas do usuário
    local clean_server_path="$server_path"
    
    # Se o server_path contém subcaminho adicional, concatenar
    if [[ "$server_path" == */* ]]; then
        # Manter exatamente como está - o PHP já aceita paths completos
        clean_server_path="$server_path"
    fi
    
    echo "🔧 DEBUG: Usando caminho servidor: '$clean_server_path'"
    
    local response=$(curl -s -X POST "$CONFIG_URL" \
        -H "Authorization: Bearer $token" \
        --data-urlencode "action=list" \
        --data-urlencode "path=$clean_server_path")
    
    echo "🔧 DEBUG: Resposta da API para listagem:"
    echo "$response" | head -10
    
    if echo "$response" | grep -q '"success":[[:space:]]*true'; then
        while IFS= read -r line; do
            if [[ "$line" =~ \"name\":[[:space:]]*\"([^\"]+)\" ]]; then
                local file_name="${BASH_REMATCH[1]}"
                if ! echo "$response" | grep -A3 -B3 "\"name\":[[:space:]]*\"$file_name\"" | grep -q '"type":[[:space:]]*"directory"'; then
                    server_files+=("$file_name")
                fi
            fi
        done <<< "$response"
    else
        echo "⚠️  Falha na listagem do servidor para: $clean_server_path"
        local error_msg=$(echo "$response" | grep -o '"message":[[:space:]]*"[^"]*"' | sed 's/.*"message":[[:space:]]*"\([^"]*\)".*/\1/')
        echo "   Erro: ${error_msg:-"Resposta inválida"}"
    fi
    
    echo
    echo "📋 COMPARAÇÃO DETALHADA:"
    echo "========================"
    echo "📂 Arquivos locais: ${#local_files[@]}"
    echo "🌐 Arquivos servidor: ${#server_files[@]}"
    echo "🔧 Caminho usado para consulta: $clean_server_path"
    
    # Encontrar diferenças
    local only_local=()
    local only_server=()
    local has_differences=false
    
    for local_file in "${local_files[@]}"; do
        local found=false
        for server_file in "${server_files[@]}"; do
            if [[ "$local_file" == "$server_file" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            only_local+=("$local_file")
            has_differences=true
        fi
    done
    
    for server_file in "${server_files[@]}"; do
        local found=false
        for local_file in "${local_files[@]}"; do
            if [[ "$server_file" == "$local_file" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            only_server+=("$server_file")
            has_differences=true
        fi
    done
    
    # Exibir resultados
    if [[ ${#only_local[@]} -gt 0 ]]; then
        echo "🆕 NOVOS NO LOCAL (${#only_local[@]}): serão enviados"
        printf '   📤 %s\n' "${only_local[@]}" | head -5
        if [[ ${#only_local[@]} -gt 5 ]]; then
            echo "   📤 ... e mais $((${#only_local[@]} - 5))"
        fi
    fi
    
    if [[ ${#only_server[@]} -gt 0 ]]; then
        echo "⚠️  SÓ NO SERVIDOR (${#only_server[@]}):"
        printf '   🌐 %s\n' "${only_server[@]}" | head -5
        if [[ ${#only_server[@]} -gt 5 ]]; then
            echo "   🌐 ... e mais $((${#only_server[@]} - 5))"
        fi
    fi
    
    if [[ ${#only_local[@]} -eq 0 && ${#only_server[@]} -eq 0 ]]; then
        echo "✅ SINCRONIZADO - Mesmo conteúdo"
        return 0
    fi
    
    # SE HÁ DIFERENÇAS, PERGUNTAR SOBRE SUBSTITUIÇÃO
    if [[ "$has_differences" == "true" ]]; then
        echo
        echo "⚠️  DIFERENÇAS DETECTADAS ENTRE LOCAL E SERVIDOR"
        echo "═════════════════════════════════════════════════"
        echo "📊 Resumo das diferenças:"
        echo "   🆕 Arquivos novos locais: ${#only_local[@]}"
        echo "   🌐 Arquivos só no servidor: ${#only_server[@]}"
        echo
        echo "💡 OPÇÕES DISPONÍVEIS:"
        echo "   1️⃣  Continuar sincronização normal (apenas novos/modificados)"
        echo "   2️⃣  SUBSTITUIR servidor pelo conteúdo local (com exclusão)"
        echo "   3️⃣  Cancelar sincronização"
        echo
        
        read -p "Escolha uma opção (1/2/3): " replace_choice </dev/tty
        
        case "$replace_choice" in
            "2")
                echo
                echo "🔄 MODO SUBSTITUIÇÃO ATIVADO"
                echo "=============================="
                echo "⚠️  ATENÇÃO: Esta operação irá:"
                echo "   🗑️  Deletar TODOS os arquivos em '$clean_server_path'"
                echo "   📤 Enviar TODO o conteúdo de '$(basename "$local_folder")'"
                echo "   ⚠️  Ação IRREVERSÍVEL"
                echo
                
                if confirm "🚨 CONFIRMAR substituição completa do servidor?"; then
                    echo
                    echo "🚀 Iniciando substituição completa..."
                    
                    # Chamar upload de pasta completa COM exclusão prévia
                    upload_pasta_completa_for_replacement "$local_folder" "$clean_server_path"
                    
                    # Marcar que foi feita substituição para pular o monitoramento normal
                    echo "REPLACEMENT_DONE" > "/tmp/upcode_replacement_flag"
                    return 0
                else
                    echo "❌ Substituição cancelada - continuando sincronização normal"
                fi
                ;;
            "3")
                echo "❌ Sincronização cancelada pelo usuário"
                echo "SYNC_CANCELLED" > "/tmp/upcode_replacement_flag"
                return 1
                ;;
            *)
                echo "ℹ️  Continuando com sincronização normal..."
                ;;
        esac
    fi
    
    return 0
}


# Função para sincronizar uma pasta local com o servidor
sync_folder_to_server() {
    local local_folder="$1"
    local server_folder="$2"
    
    if [[ ! -d "$local_folder" ]]; then
        echo "❌ Pasta local não encontrada: $local_folder"
        return 1
    fi
    
    ensure_valid_login
    
    echo "🔄 SINCRONIZAÇÃO DE PASTA"
    echo "========================"
    echo "📁 Local: $local_folder"
    echo "📁 Servidor: $server_folder"
    echo
    
    # Criar arquivo de cache se não existir
    if [[ ! -f "$SYNC_CACHE_FILE" ]]; then
        touch "$SYNC_CACHE_FILE"
    fi
    
    # Função para registrar no log de sincronização
    log_sync() {
        local message="$1"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$SYNC_LOG_FILE"
    }
    
    log_sync "Iniciando sincronização: $local_folder -> $server_folder"
    
    # Contar arquivos locais
    local total_files=$(find "$local_folder" -type f 2>/dev/null | wc -l)
    echo "📊 Total de arquivos locais: $total_files"
    
    if [[ $total_files -eq 0 ]]; then
        echo "⚠️ Nenhum arquivo encontrado para sincronizar"
        return 1
    fi
    
    # Verificar arquivos modificados desde a última sincronização
    local sync_needed=false
    local files_to_sync=()
    
    echo "🔍 Verificando arquivos modificados..."
    
    while IFS= read -r -d '' file; do
        local file_stat=$(stat -c "%Y" "$file" 2>/dev/null || echo "0")
        local cache_key="${file}|${server_folder}"
        local cached_stat=$(grep "^${cache_key}:" "$SYNC_CACHE_FILE" 2>/dev/null | cut -d':' -f2)
        
        if [[ "$file_stat" != "$cached_stat" ]]; then
            files_to_sync+=("$file")
            sync_needed=true
        fi
    done < <(find "$local_folder" -type f -print0 2>/dev/null)
    
    if [[ "$sync_needed" == "false" ]]; then
        echo "✅ Todos os arquivos estão sincronizados"
        log_sync "Nenhum arquivo precisa ser sincronizado"
        pause
        return 0
    fi
    
    echo "📤 Arquivos que serão sincronizados: ${#files_to_sync[@]}"
    
    # Mostrar lista de arquivos que serão enviados
    echo "📋 Lista de arquivos:"
    for file in "${files_to_sync[@]}"; do
        local rel_path="${file#$local_folder/}"
        echo "   📄 $rel_path"
    done | head -20
    
    if [[ ${#files_to_sync[@]} -gt 20 ]]; then
        echo "   ... e mais $((${#files_to_sync[@]} - 20)) arquivos"
    fi
    
    echo
    if confirm "🚀 Iniciar sincronização?"; then
        echo
        echo "📤 Sincronizando arquivos..."
        
        local success_count=0
        local error_count=0
        
        for file in "${files_to_sync[@]}"; do
            local filename=$(basename "$file")
            local rel_path="${file#$local_folder/}"
            local dest_path="$server_folder"
            
            # Se arquivo está em subpasta, ajustar destino
            local subdir=$(dirname "$rel_path")
            if [[ "$subdir" != "." ]]; then
                dest_path="$server_folder/$subdir"
            fi
            
            echo "⏳ Enviando: $rel_path"
            
            if perform_upload "$file" "$dest_path" "false"; then
                ((success_count++))
                
                # Atualizar cache
                local file_stat=$(stat -c "%Y" "$file" 2>/dev/null || echo "0")
                local cache_key="${file}|${server_folder}"
                
                # Remover entrada antiga do cache
                grep -v "^${cache_key}:" "$SYNC_CACHE_FILE" > "$SYNC_CACHE_FILE.tmp" 2>/dev/null || touch "$SYNC_CACHE_FILE.tmp"
                # Adicionar nova entrada
                echo "${cache_key}:${file_stat}" >> "$SYNC_CACHE_FILE.tmp"
                mv "$SYNC_CACHE_FILE.tmp" "$SYNC_CACHE_FILE"
                
                log_sync "✅ Sincronizado: $rel_path"
            else
                ((error_count++))
                log_sync "❌ Erro ao sincronizar: $rel_path"
            fi
        done
        
        echo
        echo "📊 RESULTADO DA SINCRONIZAÇÃO:"
        echo "   ✅ Sucessos: $success_count"
        echo "   ❌ Erros: $error_count"
        echo "   📊 Total processado: ${#files_to_sync[@]}"
        
        log_sync "Sincronização concluída: $success_count sucessos, $error_count erros"
        
        if [[ $success_count -gt 0 ]]; then
            echo "🎉 Sincronização concluída com sucesso!"
        fi
    else
        echo "ℹ️ Sincronização cancelada"
    fi
    
    pause
}

# Função para mostrar log de sincronização
show_sync_log() {
    clear_screen
    echo "📋 LOG DE SINCRONIZAÇÃO"
    echo "======================"
    echo
    
    if [[ -f "$SYNC_LOG_FILE" && -s "$SYNC_LOG_FILE" ]]; then
        echo "📄 Últimas 50 entradas do log:"
        echo
        tail -50 "$SYNC_LOG_FILE"
    else
        echo "ℹ️ Nenhum log de sincronização encontrado"
    fi
    
    echo
    pause
}

# Função para limpar cache e logs de sincronização
clean_sync_data() {
    echo "🧹 LIMPEZA DE DADOS DE SINCRONIZAÇÃO"
    echo "=================================="
    echo
    
    local items_to_clean=()
    
    if [[ -f "$SYNC_LOG_FILE" ]]; then
        items_to_clean+=("📋 Log de sincronização ($(wc -l < "$SYNC_LOG_FILE") linhas)")
    fi
    
    if [[ -f "$SYNC_CACHE_FILE" ]]; then
        items_to_clean+=("💾 Cache de sincronização ($(wc -l < "$SYNC_CACHE_FILE") arquivos)")
    fi
    
    if [[ ${#items_to_clean[@]} -eq 0 ]]; then
        echo "ℹ️ Nenhum dado de sincronização encontrado"
        return 0
    fi
    
    echo "📄 Itens que serão removidos:"
    printf '   %s\n' "${items_to_clean[@]}"
    echo
    
    if confirm "🗑️ Confirma a limpeza dos dados de sincronização?"; then
        rm -f "$SYNC_LOG_FILE" "$SYNC_CACHE_FILE"
        echo "✅ Dados de sincronização removidos"
    else
        echo "ℹ️ Limpeza cancelada"
    fi
}