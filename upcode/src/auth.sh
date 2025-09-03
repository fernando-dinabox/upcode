#===========================================
# FUNÇÕES DE AUTENTICAÇÃO
#===========================================

check_token() {
    if [[ -f "$TOKEN_FILE" ]]; then
        local token=$(cat "$TOKEN_FILE" 2>/dev/null)
        if [[ -n "$token" && "$token" != "null" ]]; then
            # Verificar se ainda temos as pastas do usuário E os dados do usuário
            if [[ -f "$USER_FOLDERS_FILE" && -s "$USER_FOLDERS_FILE" ]] && [[ -f "$USER_INFO_FILE" && -s "$USER_INFO_FILE" ]]; then
                load_user_info
                return 0
            fi
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
    
    # Fazer login usando a mesma estrutura do test_login.sh
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
        # Salvar token
        echo "$token" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        
        # Extrair e salvar dados do usuário
        extract_user_info "$response"
        
        # Extrair e salvar pastas do usuário
        extract_user_folders "$response"
        
        echo "✅ Login realizado com sucesso!"
        echo "👤 Usuário: $USER_DISPLAY_NAME ($USER_NICENAME)"
        echo "📧 Email: $USER_EMAIL"
        echo "🎭 Tipo: $USER_TYPE"
        local folder_count=$(echo "$response" | grep -o '"folders_count":[[:space:]]*[0-9]*' | sed 's/.*"folders_count":[[:space:]]*\([0-9]*\).*/\1/')
        echo "📁 Pastas disponíveis: $folder_count"
        
        # Carregar pastas para verificar
        load_user_folders
        echo "🔍 Debug - Pastas carregadas: ${#user_folders[@]}"
        printf '   - "%s"\n' "${user_folders[@]}"
        
        sleep 1
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
    user_folders=()
    
    # Tentar carregar do arquivo primeiro
    if [[ -f "$USER_FOLDERS_FILE" ]]; then
        while IFS= read -r folder; do
            [[ -n "$folder" ]] && user_folders+=("$folder")
        done < "$USER_FOLDERS_FILE"
    fi
    
    # recarregar via login
    if [[ ${#user_folders[@]} -eq 0 ]]; then
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
                # Re-extrair pastas
                extract_user_folders "$response"
            fi
        fi
    fi
    
    echo "🔍 Debug load_user_folders - Pastas carregadas: ${#user_folders[@]}"
    printf '   📂 "%s"\n' "${user_folders[@]}"
}



extract_user_info() {
    local response="$1"
    
    echo "🔍 Debug - Extraindo dados do usuário..."
    echo "🔍 RESPOSTA COMPLETA DO SERVIDOR:"  # ← ADICIONAR ESTA LINHA
    echo "$response"                          # ← ADICIONAR ESTA LINHA
    echo "🔍 FIM DA RESPOSTA"                # ← ADICIONAR ESTA LINHA
    
    # Extrair dados básicos do usuário
    USER_DISPLAY_NAME=$(echo "$response" | grep -o '"user_display_name":[[:space:]]*"[^"]*"' | sed 's/.*"user_display_name":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_NICENAME=$(echo "$response" | grep -o '"user_nicename":[[:space:]]*"[^"]*"' | sed 's/.*"user_nicename":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_EMAIL=$(echo "$response" | grep -o '"user_email":[[:space:]]*"[^"]*"' | sed 's/.*"user_email":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_TYPE=$(echo "$response" | grep -o '"user_type":[[:space:]]*"[^"]*"' | sed 's/.*"user_type":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_CAN_DELETE=$(echo "$response" | grep -o '"can_delete":[[:space:]]*[^,}]*' | sed 's/.*"can_delete":[[:space:]]*\([^,}]*\).*/\1/')
    
    # Extrair pastas restritas (ORDEM CORRETA)
    USER_CANNOT_DELETE_FOLDERS=()  # ← PRIMEIRO LIMPA
    local cannot_delete_list=$(echo "$response" | grep -o '"cannot_delete_folders":\[[^]]*\]')
    if [[ -n "$cannot_delete_list" ]]; then
        while IFS= read -r folder; do
            [[ -n "$folder" ]] && USER_CANNOT_DELETE_FOLDERS+=("$folder")
        done < <(echo "$cannot_delete_list" | grep -o '"[^"]*"' | sed 's/"//g' | grep -v 'cannot_delete_folders')
    fi
    
    # Salvar no arquivo (INCLUIR AS PASTAS RESTRITAS)
    cat > "$USER_INFO_FILE" << EOF
USER_DISPLAY_NAME="$USER_DISPLAY_NAME"
USER_NICENAME="$USER_NICENAME"
USER_EMAIL="$USER_EMAIL"
USER_TYPE="$USER_TYPE"
USER_CAN_DELETE="$USER_CAN_DELETE"
USER_CANNOT_DELETE_FOLDERS_STR="${USER_CANNOT_DELETE_FOLDERS[*]}"
EOF
    chmod 600 "$USER_INFO_FILE"
}

confirm_delete_option() {
    local upload_type="$1"  # "arquivo" ou "pasta"
    local target_folder="$2"  # NOVO: pasta onde será feito o upload
    
    # Verificar se tem permissão global
    if [[ "$USER_CAN_DELETE" != "true" ]]; then
        return 1  # Sem permissão global
    fi
    
    # Verificar se a pasta atual está na lista de restrições
    for restricted_folder in "${USER_CANNOT_DELETE_FOLDERS[@]}"; do
        if [[ "$target_folder" == "$restricted_folder" ]]; then
            echo
            echo "🚫 EXCLUSÃO NÃO PERMITIDA"
            echo "═══════════════════════════"
            echo "Esta pasta está protegida contra exclusão prévia."
            echo "Upload será feito SEM exclusão (arquivos serão adicionados/substituídos)"
            echo
            return 1  # Não pode deletar nesta pasta
        fi
    done
    
    # Se chegou aqui, pode deletar - mostrar opção
    echo
    echo "🗑️ OPÇÃO DE EXCLUSÃO DISPONÍVEL"
    echo "══════════════════════════════════"
    echo "Você tem permissão para deletar arquivos no destino antes do upload."
    echo
    echo "⚠️ ATENÇÃO: Esta ação irá:"
    echo "   • Deletar TODOS os arquivos na pasta de destino"
    echo "   • Enviar os novos arquivos para pasta limpa"
    echo "   • Ação IRREVERSÍVEL"
    echo
    
    if confirm "🗑️ Deletar arquivos existentes no destino antes do upload?"; then
        echo "✅ Upload será feito COM exclusão prévia"
        return 0  # Retorna true para with_delete
    else
        echo "ℹ️ Upload será feito SEM exclusão (arquivos serão adicionados/substituídos)"
        return 1  # Retorna false para with_delete
    fi
}



load_user_info() {
    if [[ -f "$USER_INFO_FILE" ]]; then
        source "$USER_INFO_FILE"
        
        # Recriar array das pastas restritas
        USER_CANNOT_DELETE_FOLDERS=()
        if [[ -n "$USER_CANNOT_DELETE_FOLDERS_STR" ]]; then
            IFS=' ' read -ra USER_CANNOT_DELETE_FOLDERS <<< "$USER_CANNOT_DELETE_FOLDERS_STR"
        fi
        
        # Só mostrar mensagem se não for chamado silenciosamente
        if [[ "$1" != "silent" ]]; then
            echo "👤 Usuário carregado: $USER_DISPLAY_NAME ($USER_NICENAME)"
        fi
    else
        USER_DISPLAY_NAME=""
        USER_NICENAME=""
        USER_EMAIL=""
        USER_TYPE=""
        USER_CAN_DELETE=""
        USER_CANNOT_DELETE_FOLDERS=()
    fi
}


ensure_valid_login() {
    load_user_folders
    load_user_info
    
    if [[ ${#user_folders[@]} -eq 0 ]] || [[ -z "$USER_DISPLAY_NAME" ]]; then
        clear_screen
        echo "⚠️ Sessão expirada ou dados inválidos"
        echo "🔄 Fazendo novo login..."
        echo
        
        # Limpar dados antigos
        rm -f "$TOKEN_FILE" "$USER_FOLDERS_FILE" "$USER_INFO_FILE"
        
        # Forçar novo login
        do_login
        
        # Recarregar dados
        load_user_folders
        load_user_info
    fi
}


extract_user_folders() {
    local response="$1"
    
    echo "🔍 Debug - Extraindo pastas..."
    
    # Método mais robusto para extrair as pastas do JSON
    # Primeiro, extrair todo o array folders
    local folders_section=$(echo "$response" | sed -n '/"folders":/,/\]/p')
    
    echo "🔍 Debug - Seção folders:"
    echo "$folders_section"
    
    # Limpar arquivo anterior
    > "$USER_FOLDERS_FILE"
    
    # Extrair cada linha que contém uma pasta (entre aspas)
    echo "$folders_section" | grep -o '"[^"]*"' | sed 's/"//g' | while read -r folder; do
        # Filtrar apenas linhas que não são palavras-chave
        if [[ "$folder" != "folders" && -n "$folder" ]]; then
            # Decodificar caracteres unicode simples
            folder=$(echo "$folder" | sed 's/\\u00e1/á/g; s/\\u00e9/é/g; s/\\u00ed/í/g; s/\\u00f3/ó/g; s/\\u00fa/ú/g; s/\\u00e7/ç/g; s/\\u00e3/ã/g; s/\\u00f5/õ/g')
            echo "$folder" >> "$USER_FOLDERS_FILE"
        fi
    done
    
    # Carregar pastas no array
    user_folders=()
    if [[ -f "$USER_FOLDERS_FILE" ]]; then
        while IFS= read -r folder; do
            [[ -n "$folder" ]] && user_folders+=("$folder")
        done < "$USER_FOLDERS_FILE"
    fi
    
    echo "📁 Pastas extraídas e carregadas: ${#user_folders[@]}"
    printf '   📂 "%s"\n' "${user_folders[@]}"
}

load_user_folders() {
    user_folders=()
    if [[ -f "$USER_FOLDERS_FILE" ]]; then
        while IFS= read -r folder; do
            [[ -n "$folder" ]] && user_folders+=("$folder")
        done < "$USER_FOLDERS_FILE"
    fi
    
    
    echo "🔍 Debug load_user_folders - Pastas carregadas: ${#user_folders[@]}"
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
        # Limpar dados antigos
        rm -f "$TOKEN_FILE" "$USER_FOLDERS_FILE" "$USER_INFO_FILE"
        
        # Limpar variáveis
        USER_DISPLAY_NAME=""
        USER_NICENAME=""
        USER_EMAIL=""
        USER_TYPE=""
        user_folders=()
        
        # Forçar novo login
        do_login
    fi
}
