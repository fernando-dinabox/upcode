upload_folder_as_complete_structure() {
    local pasta_local="$1"
    local pasta_name=$(basename "$pasta_local")
    
    if [[ ! -d "$pasta_local" ]]; then
        echo "❌ Pasta não encontrada: $pasta_local"
        pause
        return 1
    fi
    
    # Garantir login válido
    ensure_valid_login
    
    clear_screen
    echo "📦 UPLOAD DE PASTA COMPLETA (COM ESTRUTURA)"
    echo "==========================================="
    echo
    echo "📁 Pasta selecionada: '$pasta_name'"
    echo "📂 Caminho completo: $pasta_local"
    
    # Contar arquivos
    local total_files=$(find "$pasta_local" -type f 2>/dev/null | wc -l)
    echo "📊 Total de arquivos encontrados: $total_files"
    
    if [[ $total_files -eq 0 ]]; then
        echo "⚠️ Nenhum arquivo encontrado na pasta"
        pause
        return 1
    fi
    
    # Mostrar estrutura
    echo
    echo "🌳 Estrutura que será criada no servidor:"
    echo "   📂 $pasta_name/"
    find "$pasta_local" -type f 2>/dev/null | head -15 | while read -r arquivo; do
        local rel_path="${arquivo#$pasta_local/}"
        echo "   📂 $pasta_name/$rel_path"
    done
    
    if [[ $total_files -gt 15 ]]; then
        echo "   📂 $pasta_name/... e mais $((total_files - 15)) arquivos"
    fi
    
    echo
    echo "📁 Pastas disponíveis no servidor:"
    printf '   📂 %s\n' "${user_folders[@]}"
    echo
    
    # Selecionar pasta de destino
    local pasta_destino=$(printf '%s\n' "${user_folders[@]}" | \
        fzf --prompt="Pasta destino > " \
            --header="Onde criar a pasta '$pasta_name' no servidor")
    
    [[ -z "$pasta_destino" ]] && return
    
    # Verificar opção de exclusão
    local with_delete=false
    if confirm_delete_option "pasta completa" "$pasta_destino"; then
        with_delete=true
    fi
    
    echo
    echo "📋 RESUMO DA OPERAÇÃO:"
    echo "  📂 Pasta local: $pasta_name"
    echo "  📁 Será criada em: $pasta_destino/$pasta_name/"
    echo "  📊 Total de arquivos: $total_files"
    if [[ "$with_delete" == "true" ]]; then
        echo "  🗑️ Exclusão prévia: SIM (na pasta $pasta_destino/$pasta_name/)"
    else
        echo "  🗑️ Exclusão prévia: NÃO"  
    fi
    echo
    echo "💡 RESULTADO: Será criada a estrutura '$pasta_destino/$pasta_name/...' no servidor"
    
    if confirm "📦 Iniciar upload da pasta completa?"; then
        upload_pasta_completa "$pasta_local" "$pasta_destino" "$pasta_name" "$with_delete"
    fi
}


upload_folder_content_only() {
    local pasta_local="$1"
    
    if [[ ! -d "$pasta_local" ]]; then
        echo "❌ Pasta não encontrada: $pasta_local"
        pause
        return 1
    fi
    
    # Garantir login válido
    ensure_valid_login
    
    clear_screen
    echo "📤 UPLOAD DO CONTEÚDO DA PASTA"
    echo "=============================="
    echo
    echo "📁 Enviando conteúdo de: '$(basename "$pasta_local")'"
    echo "📂 Caminho: $pasta_local"
    
    # Contar arquivos
    local total_files=$(find "$pasta_local" -type f 2>/dev/null | wc -l)
    echo "📊 Total de arquivos encontrados: $total_files"
    
    if [[ $total_files -eq 0 ]]; then
        echo "⚠️ Nenhum arquivo encontrado na pasta"
        pause
        return 1
    fi
    
    # Mostrar estrutura
    echo
    echo "🌳 Arquivos que serão enviados:"
    find "$pasta_local" -type f 2>/dev/null | head -20 | while read -r arquivo; do
        local rel_path="${arquivo#$pasta_local/}"
        echo "  📄 $rel_path"
    done
    
    if [[ $total_files -gt 20 ]]; then
        echo "  ... e mais $((total_files - 20)) arquivos"
    fi
    
    echo
    echo "📁 Pastas disponíveis no servidor:"
    printf '   📂 %s\n' "${user_folders[@]}"
    echo
    
    # Selecionar pasta de destino
    local pasta_destino=$(printf '%s\n' "${user_folders[@]}" | \
        fzf --prompt="Pasta destino > " \
            --header="Onde enviar o conteúdo (sem criar pasta)")
    
    [[ -z "$pasta_destino" ]] && return
    
    # Perguntar por subpasta (opcional)
    echo
    read -p "Subpasta de destino (opcional, deixe vazio para raiz): " subpasta
    
    # Verificar opção de exclusão
    local with_delete=false
    if confirm_delete_option "conteúdo" "$pasta_destino"; then
        with_delete=true
    fi
    
    echo
    echo "📋 RESUMO DA OPERAÇÃO:"
    echo "  📂 Pasta local: $(basename "$pasta_local")"
    echo "  🎯 Destino direto: $pasta_destino"
    if [[ -n "$subpasta" ]]; then
        echo "  📁 Subpasta: $subpasta"
    fi
    echo "  📊 Total: $total_files arquivos"
    if [[ "$with_delete" == "true" ]]; then
        echo "  🗑️ Exclusão prévia: SIM"
    else
        echo "  🗑️ Exclusão prévia: NÃO"  
    fi
    echo
    echo "💡 RESULTADO: Arquivos serão colocados diretamente em '$pasta_destino'"
    
    if confirm "📤 Iniciar upload do conteúdo?"; then
        upload_pasta_completa "$pasta_local" "$pasta_destino" "$subpasta" "$with_delete"
    fi
}

show_upload_history() {
    if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
        clear_screen
        echo "📝 Histórico vazio"
        pause
        return
    fi
    
    local history_items=()
    while IFS='|' read -r item_type item_path destination timestamp; do
        if [[ "$item_type" == "file" ]] && [[ -f "$item_path" ]]; then
            history_items+=("FILE|$item_path|$destination|📄 $(basename "$item_path") → $destination")
        elif [[ "$item_type" == "folder" ]] && [[ -d "$item_path" ]]; then
            history_items+=("FOLDER|$item_path|$destination|📁 $(basename "$item_path") → $destination")
        fi
    done < <(tac "$HISTORY_FILE")
    
    if [[ ${#history_items[@]} -eq 0 ]]; then
        clear_screen
        echo "📝 Histórico vazio"
        pause
        return
    fi
    
    local choice=$(printf '%s\n' "${history_items[@]}" | \
        sed 's/^[^|]*|[^|]*|[^|]*|//' | \
        fzf --prompt="Histórico > " --header="Selecione um item para reenviar")
    
    if [[ -n "$choice" ]]; then
        for item in "${history_items[@]}"; do
            if [[ "$item" == *"|$choice" ]]; then
                local item_type=$(echo "$item" | cut -d'|' -f1)
                local selected_path=$(echo "$item" | cut -d'|' -f2)
                local last_destination=$(echo "$item" | cut -d'|' -f3)
                
                if [[ "$item_type" == "FILE" ]]; then
                    upload_single_file "$selected_path"
                elif [[ "$item_type" == "FOLDER" ]]; then
                    upload_folder_complete "$selected_path"
                fi
                break
            fi
        done
    fi
}

upload_single_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "❌ Arquivo não encontrado: $file"
        pause
        return 1
    fi
    
    # Garantir login válido
    ensure_valid_login
    
    clear_screen
    echo "📤 Upload de Arquivo"
    echo "──────────────────"
    echo "📄 Arquivo: $(basename "$file")"
    echo "💾 Tamanho: $(du -sh "$file" 2>/dev/null | cut -f1 || echo "N/A")"
    echo
    echo "📁 Pastas disponíveis: ${#user_folders[@]}"
    
    # Debug - mostrar as pastas disponíveis
    if [[ ${#user_folders[@]} -eq 0 ]]; then
        echo "❌ Nenhuma pasta disponível!"
        echo "🔄 Tentando recarregar..."
        load_user_folders
        if [[ ${#user_folders[@]} -eq 0 ]]; then
            echo "❌ Ainda sem pastas - forçando novo login..."
            ensure_valid_login
        fi
    fi
    
    #echo "🔍 Debug - Pastas para seleção:"
    printf '   📂 "%s"\n' "${user_folders[@]}"
    #echo
    
    local folder=$(printf '%s\n' "${user_folders[@]}" | \
        fzf --prompt="Pasta de destino > " \
            --header="Selecione onde enviar o arquivo" \
            --height=$((${#user_folders[@]} + 5)))
    
    [[ -z "$folder" ]] && return
    
    # Verificar opção de exclusão - CORRIGIDO: usar $folder em vez de $selected_folder
    local with_delete=false
    if confirm_delete_option "arquivo" "$folder"; then
        with_delete="true"
    else
        with_delete="false"
    fi
    
    if confirm "Confirmar upload?"; then
        if perform_upload "$file" "$folder" "$with_delete"; then
            add_to_history "$file" "file" "$folder"
        fi
    fi
}



quick_upload() {
    if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
        echo "📝 Histórico vazio - use o navegador de arquivos primeiro"
        pause
        return
    fi
    
    local last_item=$(tail -n 1 "$HISTORY_FILE")
    local item_type=$(echo "$last_item" | cut -d'|' -f1)
    local item_path=$(echo "$last_item" | cut -d'|' -f2)
    
    if [[ "$item_type" == "file" && -f "$item_path" ]]; then
        upload_single_file "$item_path"
    elif [[ "$item_type" == "folder" && -d "$item_path" ]]; then
        upload_folder_complete "$item_path"
    else
        echo "❌ Último item não está mais disponível"
        pause
    fi
}

upload_folder_complete() {
    local pasta_local="$1"
    
    if [[ ! -d "$pasta_local" ]]; then
        echo "❌ Pasta não encontrada: $pasta_local"
        pause
        return 1
    fi
    
    # Garantir login válido
    ensure_valid_login
    
    clear_screen
    echo "📁 UPLOAD DE PASTA COMPLETA"
    echo "============================"
    echo
    echo "📁 Analisando pasta '$pasta_local'..."
    
    # Contar arquivos
    local total_files=$(find "$pasta_local" -type f 2>/dev/null | wc -l)
    echo "📊 Total de arquivos encontrados: $total_files"
    
    if [[ $total_files -eq 0 ]]; then
        echo "⚠️ Nenhum arquivo encontrado na pasta"
        pause
        return 1
    fi
    
    # Mostrar estrutura
    echo "🌳 Estrutura da pasta:"
    find "$pasta_local" -type f 2>/dev/null | head -20 | while read -r arquivo; do
        echo "  📄 $arquivo"
    done
    
    if [[ $total_files -gt 20 ]]; then
        echo "  ... e mais $((total_files - 20)) arquivos"
    fi
    
    echo
    echo "📁 Pastas disponíveis no servidor:"
    printf '   📂 %s\n' "${user_folders[@]}"
    echo
    
    # Selecionar pasta de destino
    local pasta_destino=$(printf '%s\n' "${user_folders[@]}" | \
        fzf --prompt="Pasta destino > " \
            --header="Selecione a pasta de destino no servidor")
    
    [[ -z "$pasta_destino" ]] && return
    
    # Perguntar por subpasta (opcional)
    echo
    read -p "Subpasta de destino (opcional, deixe vazio para raiz): " subpasta
    
    # Verificar opção de exclusão
    local with_delete=false
    if confirm_delete_option "pasta" "$pasta_destino"; then
        with_delete=true
    fi
    
    echo
    echo "📋 RESUMO:"
    echo "  📂 Pasta local: $pasta_local"
    echo "  🎯 Destino: $pasta_destino"
    if [[ -n "$subpasta" ]]; then
        echo "  📁 Subpasta: $subpasta"
    fi
    echo "  📊 Total: $total_files arquivos"
    if [[ "$with_delete" == "true" ]]; then
        echo "  🗑️ Exclusão prévia: SIM"
    else
        echo "  🗑️ Exclusão prévia: NÃO"  
    fi
    
    if confirm "📤 Iniciar upload de pasta completa?"; then
        upload_pasta_completa "$pasta_local" "$pasta_destino" "$subpasta" "$with_delete"
    fi
}

upload_pasta_completa() {
    local pasta_local="$1"
    local pasta_destino="$2"
    local subpasta="$3"
    local with_delete_param="$4"  

    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        echo "❌ Token não encontrado"
        return 1
    fi
    
    echo
    echo "📤 Iniciando upload de pasta completa..."
    echo "🔑 Token: ${token:0:30}..."
    
    # DEBUG: Verificar valor recebido
    echo "🔍 DEBUG - Parâmetro with_delete recebido: '$with_delete_param'"
    
    if [[ "$with_delete_param" == "true" ]]; then
        echo "🗑️ COM exclusão prévia dos arquivos existentes"
    else
        echo "ℹ️ SEM exclusão prévia"
    fi
    echo
    
    # Contadores
    local upload_count=0
    local success_count=0
    local error_count=0
    local delete_applied=false
    
    # Arrays para armazenar detalhes dos erros
    local error_files=()
    local error_details=()
    
    # Criar array com todos os arquivos primeiro
    local files_array=()
    while IFS= read -r -d '' arquivo; do
        files_array+=("$arquivo")
    done < <(find "$pasta_local" -type f -print0 2>/dev/null)
    
    echo "📊 Total de arquivos a processar: ${#files_array[@]}"
    echo
    
    # Upload de cada arquivo mantendo a estrutura
    for arquivo in "${files_array[@]}"; do
        # Calcular o caminho relativo do arquivo atual
        local rel_path="${arquivo#$pasta_local/}"
        
        # Adicionar subpasta se especificada
        local dest_path="$rel_path"
        if [[ -n "$subpasta" ]]; then
            dest_path="$subpasta/$rel_path"
        fi
        
        # Remover barras duplicadas
        dest_path=$(echo "$dest_path" | sed 's|/\+|/|g')
        dest_path="${dest_path#/}"
        dest_path="${dest_path%/}"
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📤 ENVIANDO ARQUIVO $((upload_count + 1))/${#files_array[@]}"
        # echo "📄 Arquivo local: $(basename "$arquivo")"
        # echo "📁 Caminho relativo: $rel_path"
        # echo "🎯 Destino normalizado: $dest_path"
        echo "💾 Tamanho: $(du -sh "$arquivo" 2>/dev/null | cut -f1 || echo "N/A")"
        
        
        local corrected_file="$arquivo"
        if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
            if [[ "$arquivo" =~ ^/c/ ]]; then
                corrected_file=$(echo "$arquivo" | sed 's|^/c|C:|')
                #echo "🔧 Caminho corrigido para Windows: $corrected_file"
            fi
        fi
        
        # Construir comando curl
        local curl_cmd=(
            curl -s -X POST "$CONFIG_URL"
            -H "Authorization: Bearer $token"
            -F "arquivo[]=@$corrected_file"
            -F "pasta=$pasta_destino"
        )
        
        # DEBUG: Estado do delete
        #echo "🔍 DEBUG - Verificação do delete:"
        echo "  with_delete_param: '$with_delete_param'"
        # echo "  delete_applied: '$delete_applied'"
        # echo "  Vai aplicar delete? $([[ "$with_delete_param" == "true" && "$delete_applied" == "false" ]] && echo "SIM" || echo "NÃO")"
        
        # Aplicar with_delete apenas no PRIMEIRO arquivo
        if [[ "$with_delete_param" == "true" && "$delete_applied" == "false" ]]; then
            curl_cmd+=(-F "with_delete=true")
            # Especificar onde deletar baseado na subpasta
            if [[ -n "$subpasta" ]]; then
                curl_cmd+=(-F "delete_folder=$subpasta")  # Testar este parâmetro
            fi
            delete_applied=true
        fi

        
        # Adicionar path apenas se não estiver vazio
        if [[ -n "$dest_path" && "$dest_path" != "." ]]; then
            curl_cmd+=(-F "path=$dest_path")
            echo "📁 Adicionando path: $dest_path"
        fi
        
        # DEBUG: Mostrar comando curl completo
        echo
        #echo "🔧 DEBUG - Array completo do curl_cmd:"
        # for i in "${!curl_cmd[@]}"; do
        #     if [[ "${curl_cmd[$i]}" == *"Authorization: Bearer"* ]]; then
        #         #echo "  [$i]: 'Authorization: Bearer ${token:0:10}...***'"
        #     elif [[ "${curl_cmd[$i]}" == *"@"* ]]; then
        #         #echo "  [$i]: 'arquivo[]=@$(basename "${curl_cmd[$i]#*@}")'"
        #     else
        #         #echo "  [$i]: '${curl_cmd[$i]}'"
        #     fi
        # done
        echo
        
        # Executar upload
        echo "⏳ Executando upload..."
        local start_time=$(date +%s)
        local response=$("${curl_cmd[@]}" 2>&1)
        local curl_exit=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # NOVO DEBUG: Verificar se a API realmente recebeu o with_delete
        #echo "🔍 TESTE DEBUG - Resposta sobre delete:"
        if echo "$response" | grep -i -E "(delet|remov|clean|clear)" | head -3; then
            echo "   ✅ API mencionou operação de delete"
        else
            echo "   ❌ API NÃO mencionou delete na resposta"
        fi
        
        ((upload_count++))
        
        # echo "⌛ Tempo de upload: ${duration}s"
        # echo "🔍 Exit code curl: $curl_exit"
        
        # Análise da resposta
        if [[ $curl_exit -ne 0 ]]; then
            echo "❌ ERRO CURL (Exit Code: $curl_exit)"
            error_files+=("$(basename "$arquivo")")
            error_details+=("CURL_ERROR_$curl_exit")
            ((error_count++))
            continue
        fi
        
        # Verificar sucesso
        if echo "$response" | grep -q '"success":[[:space:]]*true'; then
            echo "🎉 ✅ SUCESSO - Arquivo enviado com êxito!"
            ((success_count++))
        else
            echo "💥 ❌ FALHA - Arquivo não foi enviado"
            local error_message=$(echo "$response" | grep -o '"message":[[:space:]]*"[^"]*"' | sed 's/.*"message":[[:space:]]*"\([^"]*\)".*/\1/')
            error_files+=("$(basename "$arquivo")")
            error_details+=("${error_message:-"Erro desconhecido"}")
            ((error_count++))
        fi
        
        sleep 0.1
    done
    
    # Resumo final
    echo
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                           📊 RESUMO FINAL DETALHADO                 ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║ 📁 Pasta local: $pasta_local"
    echo "║ 🎯 Destino: $pasta_destino"
    if [[ -n "$subpasta" ]]; then
        echo "║ 📂 Subpasta: $subpasta"
    fi
    if [[ "$with_delete_param" == "true" ]]; then
        echo "║ 🗑️ Exclusão prévia: APLICADA"
    fi
    echo "║ ✅ Sucessos: $success_count"
    echo "║ ❌ Erros: $error_count" 
    echo "║ 📊 Total processado: $upload_count"
    if [[ $upload_count -gt 0 ]]; then
        echo "║ 📈 Taxa de sucesso: $(( success_count * 100 / upload_count ))%"
    fi
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    
    if [[ $success_count -gt 0 ]]; then
        add_to_history "$pasta_local" "folder" "$pasta_destino"
        echo "🎉 Upload de pasta concluído com $success_count sucessos!"
    else
        echo "💥 Nenhum arquivo foi enviado com sucesso"
    fi
    
    pause
}

perform_upload() {
    local file="$1"
    local folder="$2"
    local with_delete="$3"
    
    if [[ ! -f "$file" ]]; then
        echo "❌ Arquivo não encontrado: $file"
        return 1
    fi
    
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        echo "❌ Token não encontrado"
        return 1
    fi
    
    # Corrigir caminho para curl
    local corrected_file="$file"
    if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
        if [[ "$file" =~ ^/c/ ]]; then
            corrected_file=$(echo "$file" | sed 's|^/c|C:|')
        fi
    fi
    
    local filename=$(basename "$corrected_file")
    echo "🔄 Enviando $filename para pasta: $folder"
    
    echo
    echo "🔧 Detalhes do envio:"
    echo "─────────────────────────"
    echo "  📡 URL: $CONFIG_URL"
    # echo "  🔑 Token: ${token:0:20}..."
    echo "  📄 Arquivo: $filename"
    echo "  📁 Pasta destino: $folder"
    if [[ "$with_delete" == "true" ]]; then
        echo "  🗑️ Com exclusão prévia: SIM"
    else
        echo "  🗑️ Com exclusão prévia: NÃO"
    fi
    
    # Construir comando curl IGUAL ao test_upload_file.sh
    local curl_cmd=(
        curl -s -X POST "$CONFIG_URL"
        -H "Authorization: Bearer $token"
        -F "arquivo[]=@$corrected_file"
        -F "pasta=$folder"
    )
    
    # Adicionar with_delete se necessário
    if [[ "$with_delete" == "true" ]]; then
        curl_cmd+=(-F "with_delete=true")
    fi
    
    # Mostrar comando curl mascarado
    # echo
    # echo "🔍 PARÂMETROS ENVIADOS:"
    # echo "  -H \"Authorization: Bearer ${token:0:10}...***\""
    # echo "  -F \"arquivo[]=@$filename\""
    # echo "  -F \"pasta=$folder\""
    # if [[ "$with_delete" == "true" ]]; then
    #     echo "  -F \"with_delete=true\""
    # fi
    # echo
    
    # Executar upload
    #echo "⏳ Executando upload..."
    local start_time=$(date +%s)
    local response=$("${curl_cmd[@]}" 2>&1)
    local curl_exit=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "⌛ Tempo de execução: ${duration}s"
    #echo "🔍 Exit code: $curl_exit"
    
    # Análise detalhada da resposta
    # echo
    # echo "📋 ANÁLISE DA RESPOSTA:"
    # echo "─────────────────────"
    
    if [[ $curl_exit -ne 0 ]]; then
        echo "❌ ERRO CURL (Exit Code: $curl_exit)"
        case $curl_exit in
            6) echo "   💥 Não conseguiu resolver hostname" ;;
            7) echo "   🔌 Falha na conexão" ;;
            28) echo "   ⏰ Timeout da operação" ;;
            35) echo "   🔒 Erro SSL/TLS" ;;
            *) echo "   ❓ Erro desconhecido ($curl_exit)" ;;
        esac
        echo "   📄 Resposta: ${response:0:200}..."
        pause
        return 1
    fi
    
    # Verificar se é JSON válido
    if [[ "$response" =~ ^\{.*\}$ ]] || [[ "$response" =~ ^\[.*\]$ ]]; then
        #echo "✅ Resposta é JSON válido"
        
        # Extrair informações do JSON
        local success_status=$(echo "$response" | grep -o '"success":[[:space:]]*[^,}]*' | sed 's/.*"success":[[:space:]]*\([^,}]*\).*/\1/')
        local message=$(echo "$response" | grep -o '"message":[[:space:]]*"[^"]*"' | sed 's/.*"message":[[:space:]]*"\([^"]*\)".*/\1/')
        
        #echo "   🎯 Status: ${success_status:-"não encontrado"}"
        #echo "   💬 Mensagem: ${message:-"não encontrada"}"
        
        # # Mostrar resposta completa para debug
        # echo
        # echo "📄 RESPOSTA COMPLETA:"
        # echo "─────────────────────"
        # echo "$response" | head -20
        
    else
        echo "⚠️ Resposta NÃO é JSON válido"
        echo "   📄 Conteúdo: $(echo "$response" | head -c 100)..."
    fi
    
    # Verificar sucesso final
    echo
    if echo "$response" | grep -q '"success":[[:space:]]*true'; then
        echo "🎉 ✅ SUCESSO - $filename enviado com êxito!"

        if [[ "$with_delete" == "true" ]]; then
            echo "🗑️ Arquivos antigos foram removidos do destino"
        fi
        echo "📁 Arquivo enviado para: $folder"
        echo
        pause             
        return 0
    else
        echo "💥 ❌ FALHA - $filename não foi enviado"
        
        # Tentar extrair erro específico
        local error_msg=$(echo "$response" | grep -o '"message":[[:space:]]*"[^"]*"' | sed 's/.*"message":[[:space:]]*"\([^"]*\)".*/\1/')
        if [[ -n "$error_msg" ]]; then
            echo "   📝 Erro: $error_msg"
        fi
        
        echo
        pause           
        return 1
    fi
}


# Função para upload de pasta completa preservando estrutura
perform_complete_folder_upload() {
    local folder="$1"
    local destination="$2"
    
    if [[ ! -d "$folder" ]]; then
        echo "❌ Pasta não encontrada: $folder"
        return 1
    fi
    
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        echo "❌ Token não encontrado"
        return 1
    fi
    
    local folder_name=$(basename "$folder")
    echo "🚀 Iniciando upload completo de: $folder_name"
    echo
    
    # Coletar todos os arquivos
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$folder" -type f -print0 2>/dev/null)
    
    local total_files=${#files[@]}
    local current=0
    local success=0
    local failed=0
    
    echo "📊 Total de arquivos: $total_files"
    echo "🚀 Iniciando envio com preservação de estrutura..."
    echo
    
    # Upload cada arquivo preservando estrutura
    for file in "${files[@]}"; do
        ((current++))
        local filename=$(basename "$file")
        local relative_path="${file#$folder/}"
        local relative_dir=$(dirname "$relative_path")
        
        # Determinar pasta de destino final
        local final_destination="$destination"
        if [[ "$relative_dir" != "." ]]; then
            # Arquivo está em subpasta - criar estrutura no servidor
            final_destination="$destination/$relative_dir"
        fi
        
        # Corrigir caminho para curl
        local corrected_file="$file"
        if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
            if [[ "$file" =~ ^/c/ ]]; then
                corrected_file=$(echo "$file" | sed 's|^/c|C:|')
            fi
        fi
        
        echo "[$current/$total_files] 📤 $relative_path"
        if [[ "$relative_dir" != "." ]]; then
            echo "   📁 Criando: $relative_dir/"
        fi
        
        # Fazer upload
        local response=$(curl -s -X POST \
            -H "Cookie: jwt_user=$token; user_jwt=$token" \
            -F "arquivo[]=@$corrected_file" \
            -F "pasta=$final_destination" \
            "$CONFIG_URL" 2>&1)
        
        local curl_exit=$?
        
        if [[ $curl_exit -eq 0 ]] && echo "$response" | grep -q -E "(enviados com sucesso|upload.*sucesso|success)"; then
            echo "   ✅ Sucesso"
            ((success++))
        else
            echo "   ❌ Falha"
            ((failed++))
        fi
    done
    
    echo
    echo "   📊 Resultado final:"
    echo "   ✅ Sucessos: $success"
    echo "   ❌ Falhas: $failed"
    echo "   📊 Total: $total_files"
    
    if [[ $success -gt 0 ]]; then
        echo "✅ Upload da estrutura concluído!"
        echo "📁 Estrutura de pastas preservada no servidor"
        pause
        return 0
    else
        echo "❌ Nenhum arquivo foi enviado com sucesso"
        pause
        return 1
    fi
}

