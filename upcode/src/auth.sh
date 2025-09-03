#===========================================
# FUNÇÕES DE AUTENTICAÇÃO
#===========================================

check_token() {
    if [[ -f "$TOKEN_FILE" ]]; then
        local token=$(cat "$TOKEN_FILE" 2>/dev/null)
        if [[ -n "$token" && "$token" != "null" ]]; then
            return 0
        fi
    fi
    return 1
}


do_login() {
    echo "🔐 Login necessário"
    echo "─────────────────"
    
    read -p "👤 Usuário: " username </dev/tty
    read -s -p "🔑 Senha: " password </dev/tty
    echo
    
    if [[ -z "$username" || -z "$password" ]]; then
        echo "❌ Usuário e senha são obrigatórios!"
        pause
        exit 1
    fi
    
    echo "🔄 Autenticando..."
    
    local response=$(curl -s -X POST "$AUTH_URL" \
        -d "action=login" \
        -d "username=$username" \
        -d "password=$password")
    
    echo "🔍 Debug - Resposta do servidor:"
    echo "$response" | head -10
    sleep 3
    echo
    
    # Extrair token
    local token=$(echo "$response" | grep -o '"token":[[:space:]]*"[^"]*"' | sed 's/.*"token":[[:space:]]*"\([^"]*\)".*/\1/')
    
    if [[ -n "$token" && "$token" != "null" ]]; then
        # Salvar APENAS o token
        echo "$token" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        
        # CORREÇÃO: Extrair dados na ordem correta
        extract_user_info "$response"
        extract_user_folders "$response"
        
        echo "✅ Login realizado com sucesso!"
        echo "👤 Usuário: $USER_DISPLAY_NAME ($USER_NICENAME)"
        echo "📧 Email: $USER_EMAIL"
        echo "🎭 Tipo: $USER_TYPE"
        local folder_count=$(echo "$response" | grep -o '"folders_count":[[:space:]]*[0-9]*' | sed 's/.*"folders_count":[[:space:]]*\([0-9]*\).*/\1/')
        echo "📁 Pastas disponíveis: $folder_count"
        echo "🔍 Debug - Pastas carregadas: ${#user_folders[@]}"
        printf '   - "%s"\n' "${user_folders[@]}"
        
        # PAUSA PARA VER RESULTADO
        echo
        echo "Pressione ENTER para continuar..."
        read -r
        
        return 0
    else
        echo "❌ Falha na autenticação!"
        echo "🔍 Resposta do servidor:"
        echo "$response" | head -5
        pause
        exit 1
    fi
}

load_user_folders() {
    # Se já temos pastas em memória, não fazer nada
    if [[ ${#user_folders[@]} -gt 0 ]]; then
        echo "🔍 Debug load_user_folders - Pastas já em memória: ${#user_folders[@]}"
        printf '   📂 "%s"\n' "${user_folders[@]}"
        return 0
    fi
    
    # Se não tem pastas, tentar recarregar do servidor
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -n "$token" ]]; then
        echo "🔧 Recarregando pastas do servidor..."
        local response=$(curl -s -X POST "$CONFIG_URL" \
            -H "Authorization: Bearer $token" \
            -d "action=update_folders")
        
        if echo "$response" | grep -q '"success":[[:space:]]*true'; then
            extract_user_folders "$response"
        fi
    fi
    
    echo "🔍 Debug load_user_folders - Pastas finais: ${#user_folders[@]}"
    printf '   📂 "%s"\n' "${user_folders[@]}"
}


extract_user_info() {
    local response="$1"
    
    mkdir -p "$UPCODE_DIR"
    
    echo "🔍 Debug - Extraindo dados do usuário..."
    
    # Extrair dados básicos
    USER_DISPLAY_NAME=$(echo "$response" | grep -o '"user_display_name":[[:space:]]*"[^"]*"' | sed 's/.*"user_display_name":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_NICENAME=$(echo "$response" | grep -o '"user_nicename":[[:space:]]*"[^"]*"' | sed 's/.*"user_nicename":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_EMAIL=$(echo "$response" | grep -o '"user_email":[[:space:]]*"[^"]*"' | sed 's/.*"user_email":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_TYPE=$(echo "$response" | grep -o '"user_type":[[:space:]]*"[^"]*"' | sed 's/.*"user_type":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_CAN_DELETE=$(echo "$response" | grep -o '"can_delete":[[:space:]]*[^,}]*' | sed 's/.*"can_delete":[[:space:]]*\([^,}]*\).*/\1/')
    
    # Extrair array de pastas restritas e criar string
    USER_CANNOT_DELETE_FOLDERS=()
    local cannot_delete_list=$(echo "$response" | grep -o '"cannot_delete_folders":\[[^]]*\]')
    if [[ -n "$cannot_delete_list" ]]; then
        while IFS= read -r folder; do
            [[ -n "$folder" ]] && USER_CANNOT_DELETE_FOLDERS+=("$folder")
        done < <(echo "$cannot_delete_list" | grep -o '"[^"]*"' | sed 's/"//g' | grep -v 'cannot_delete_folders')
    fi
    
    # Criar string separada por espaços
    USER_CANNOT_DELETE_FOLDERS_STR="${USER_CANNOT_DELETE_FOLDERS[*]}"
    
    # Salvar arquivo
    cat > "$USER_INFO_FILE" << EOF
USER_DISPLAY_NAME="$USER_DISPLAY_NAME"
USER_NICENAME="$USER_NICENAME"
USER_EMAIL="$USER_EMAIL"
USER_TYPE="$USER_TYPE"
USER_CAN_DELETE="$USER_CAN_DELETE"
USER_CANNOT_DELETE_FOLDERS_STR="$USER_CANNOT_DELETE_FOLDERS_STR"
EOF


    # CRIAR ARQUIVO SEPARADO para pastas restritas (uma pasta por linha)
    > "$RESTRICTED_FOLDERS_FILE"
    if [[ ${#USER_CANNOT_DELETE_FOLDERS[@]} -gt 0 ]]; then
        printf '%s\n' "${USER_CANNOT_DELETE_FOLDERS[@]}" > "$RESTRICTED_FOLDERS_FILE"
    fi
    chmod 600 "$RESTRICTED_FOLDERS_FILE"
    
    echo "📁 Pastas restritas salvas em arquivo separado: ${#USER_CANNOT_DELETE_FOLDERS[@]} pastas"
    chmod 600 "$USER_INFO_FILE"
    
    echo "🔍 Dados salvos:"
    echo "  USER_CAN_DELETE = '$USER_CAN_DELETE'"
    echo "  USER_CANNOT_DELETE_FOLDERS_STR = '$USER_CANNOT_DELETE_FOLDERS_STR'"
}



confirm_delete_option() {
    local upload_type="$1"
    local target_folder="$2"
    
    # SEMPRE mostrar opção (PHP vai validar)
    echo
    echo "🗑️ OPÇÃO DE EXCLUSÃO"
    echo "Deseja deletar arquivos existentes antes do upload?"
    echo "⚠️ Esta operação será validada pelo servidor."
    echo
    
    if confirm "🗑️ Deletar arquivos existentes no destino antes do upload?"; then
        return 0  # Com exclusão
    else
        return 1  # Sem exclusão
    fi
}


load_user_info() {
    if [[ -f "$USER_INFO_FILE" ]]; then
        source "$USER_INFO_FILE"
        # Só mostrar debug se não for chamado silenciosamente
        if [[ "$1" != "silent" ]]; then
            echo "🔍 LOAD DEBUG: USER_CANNOT_DELETE_FOLDERS_STR='$USER_CANNOT_DELETE_FOLDERS_STR'"
        fi
        # Recriar array das pastas restritas
        USER_CANNOT_DELETE_FOLDERS=()
        if [[ -n "$USER_CANNOT_DELETE_FOLDERS_STR" ]] && [[ "$USER_CANNOT_DELETE_FOLDERS_STR" != "" ]]; then
            IFS=' ' read -ra USER_CANNOT_DELETE_FOLDERS <<< "$USER_CANNOT_DELETE_FOLDERS_STR"
        fi
        
        # Só mostrar mensagem se não for chamado silenciosamente
        if [[ "$1" != "silent" ]]; then
            echo "👤 Usuário carregado: $USER_DISPLAY_NAME ($USER_NICENAME)"
        fi

    fi
}


ensure_valid_login() {
    # NOVA LÓGICA: Verificar apenas token e pastas em memória
    local has_valid_token=false
    local has_folders=false
    
    # Verificar token
    if [[ -f "$TOKEN_FILE" ]]; then
        local token=$(cat "$TOKEN_FILE" 2>/dev/null)
        if [[ -n "$token" && "$token" != "null" ]]; then
            has_valid_token=true
        fi
    fi
    
    # Verificar pastas em memória
    if [[ ${#user_folders[@]} -gt 0 ]]; then
        has_folders=true
    fi
    
    # Debug
    echo "🔍 DEBUG ensure_valid_login:"
    echo "  Token válido: $has_valid_token"
    echo "  Pastas em memória: $has_folders (${#user_folders[@]} pastas)"
    
    # Se tem token E pastas, está OK
    if [[ "$has_valid_token" == "true" && "$has_folders" == "true" ]]; then
        echo "  ✅ Sessão válida - continuando"
        return 0
    fi
    
    # Se não tem token OU pastas, fazer novo login
    clear_screen
    echo "⚠️ Sessão inválida ou dados incompletos"
    echo "🔄 Fazendo novo login..."
    echo "  Token: $has_valid_token"
    echo "  Pastas: $has_folders"
    echo
    
    # Limpar dados antigos
    rm -f "$TOKEN_FILE" "$USER_INFO_FILE"
    
    # Limpar variáveis em memória
    user_folders=()
    USER_DISPLAY_NAME=""
    USER_NICENAME=""
    
    # Forçar novo login
    do_login
}

extract_user_folders() {
    local response="$1"
    
    echo "🔍 Debug - Extraindo pastas..."
    
    # Extrair todo o array folders
    local folders_section=$(echo "$response" | sed -n '/"folders":/,/\]/p')
    
    echo "🔍 Debug - Seção folders:"
    echo "$folders_section"
    
    # CORREÇÃO: Limpar array antes de preencher
    user_folders=()
    
    # NOVA ABORDAGEM: Usar um loop diferente
    local temp_file=$(mktemp)
    echo "$folders_section" | grep -o '"[^"]*"' | sed 's/"//g' > "$temp_file"
    
    while IFS= read -r folder; do
        if [[ "$folder" != "folders" && -n "$folder" ]]; then
            # Decodificar caracteres unicode simples
            folder=$(echo "$folder" | sed 's/\\u00e1/á/g; s/\\u00e9/é/g; s/\\u00ed/í/g; s/\\u00f3/ó/g; s/\\u00fa/ú/g; s/\\u00e7/ç/g; s/\\u00e3/ã/g; s/\\u00f5/õ/g')
            user_folders+=("$folder")
            echo "📂 Adicionada pasta: '$folder'"
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    # NÃO SALVAR EM ARQUIVO - APENAS EM MEMÓRIA
    echo "📁 Pastas extraídas para MEMÓRIA: ${#user_folders[@]}"
    printf '   📂 "%s"\n' "${user_folders[@]}"
}

renew_token() {
    clear_screen
    echo "🔄 Renovar Token"
    echo "──────────────"
    echo
    
    if [[ -n "$USER_DISPLAY_NAME" ]]; then
        echo "👤 Usuário atual: $USER_DISPLAY_NAME ($USER_NICENAME)"
        echo
    fi
    
    if confirm "Fazer novo login?"; then
        # Limpar APENAS o token
        rm -f "$TOKEN_FILE"
        
        # Limpar variáveis EM MEMÓRIA
        USER_DISPLAY_NAME=""
        USER_NICENAME=""
        USER_EMAIL=""
        USER_TYPE=""
        USER_CAN_DELETE=""
        user_folders=()  # ← Limpar array de pastas
        
        # Forçar novo login
        do_login
    fi
}

