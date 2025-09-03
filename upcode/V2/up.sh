CURRENT_VERSION="1.0.4"
CONFIG_URL="https://db33.dev.dinabox.net/upcode/upcode.php" 
AUTH_URL="https://db33.dev.dinabox.net/upcode/upcode.php"  
TOKEN_FILE="$HOME/.upcode_token"
HISTORY_FILE="$HOME/.upcode_history"
USER_FOLDERS_FILE="$HOME/.upcode_user_folders" 
USER_INFO_FILE="$HOME/.upcode_user_info" 
USER_CAN_DELETE=""
SYNC_LOG_FILE="$HOME/.upcode_sync.log"
SYNC_CACHE_FILE="$HOME/.upcode_sync.cache"
USER_FOLDER_PERMISSIONS_FILE="$HOME/.upcode_folder_permissions"  # Novo arquivo para permissões

# Array para arquivos selecionados
declare -a selected_files=()
declare -a user_folders=()  # Array para as pastas do usuário

# Variáveis para dados do usuário logado
USER_DISPLAY_NAME=""
USER_NICENAME=""
USER_EMAIL=""
USER_TYPE=""

# Configurações de interface
FZF_DEFAULT_OPTS="--height=40% --border --margin=1 --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9"


#===========================================
# BANNER E INTERFACE
#===========================================

show_banner() {
    clear
    echo "
    ██╗   ██╗██████╗  ██████╗ ██████╗ ██████╗ ███████╗
    ██║   ██║██╔══██╗██╔════╝██╔═══██╗██╔══██╗██╔════╝
    ██║   ██║██████╔╝██║     ██║   ██║██║  ██║█████╗  
    ██║   ██║██╔═══╝ ██║     ██║   ██║██║  ██║██╔══╝  
    ╚██████╔╝██║     ╚██████╗╚██████╔╝██████╔╝███████╗
     ╚═════╝ ╚═╝      ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
    "
    echo "    🚀 Sistema de upload arquivos via terminal. v$CURRENT_VERSION"
    echo "    ═══════════════════════════════════════════════"
    echo
    
    # Aguardar 2 segundos
    sleep 1
}


# Limpar tela (modificado para mostrar versão)
clear_screen() {
    clear
    echo "🚀 UPCODE v$CURRENT_VERSION - Sistema de Upload"
    echo "═════════════════════════════════════════════════"
    echo
}



# FORÇAR VERIFICAÇÃO DE VERSÃO NO INÍCIO
force_update_check() {
    echo "🔍 Verificando versão mais recente..."
    local remote_content=$(curl -s "$UPDATE_URL?v=$(date +%s)" 2>/dev/null)
    
    if [[ -n "$remote_content" ]]; then
        local remote_version=$(echo "$remote_content" | grep '^CURRENT_VERSION=' | head -1 | cut -d'"' -f2)
        
        if [[ -n "$remote_version" && "$remote_version" != "$CURRENT_VERSION" ]]; then
            echo "🆕 Nova versão disponível: $remote_version (atual: $CURRENT_VERSION)"
            echo "🔄 Executando versão mais recente..."
            echo "$remote_content" | bash
            exit 0
        else
            echo "✅ Executando versão atual ($CURRENT_VERSION)"
        fi
    fi
}

# Chamar verificação no início
force_update_check

# Instalação automática do Fuzzy Finder (FZF) se não estiver presente
install_fzf() {
    echo "📦 FZF não encontrado - tentando instalação automática..."
    echo
    
    # Detectar sistema e tentar instalação
    if command -v scoop &> /dev/null; then
        echo "🔄 Instalando via Scoop..."
        if scoop install fzf; then
            echo "✅ FZF instalado com sucesso via Scoop!"
            return 0
        fi
    elif command -v choco &> /dev/null; then
        echo "🔄 Instalando via Chocolatey..."
        if choco install fzf -y; then
            echo "✅ FZF instalado com sucesso via Chocolatey!"
            return 0
        fi
    elif command -v winget &> /dev/null; then
        echo "🔄 Instalando via WinGet..."
        if winget install fzf; then
            echo "✅ FZF instalado com sucesso via WinGet!"
            return 0
        fi
    elif command -v apt &> /dev/null; then
        echo "🔄 Instalando via APT..."
        if sudo apt update && sudo apt install -y fzf; then
            echo "✅ FZF instalado com sucesso via APT!"
            return 0
        fi
    elif command -v brew &> /dev/null; then
        echo "🔄 Instalando via Homebrew..."
        if brew install fzf; then
            echo "✅ FZF instalado com sucesso via Homebrew!"
            return 0
        fi
    else
        echo "❌ Nenhum gerenciador de pacotes suportado encontrado"
        echo "📋 Instale FZF manualmente:"
        echo "   Windows: scoop install fzf  OU  choco install fzf"
        echo "   Linux: sudo apt install fzf"
        return 1
    fi
}


#===========================================
# UTILITÁRIOS E FUNÇÕES GERAIS
#===========================================

check_dependencies() {
    
    if ! command -v fzf &> /dev/null; then
        echo "❌ FZF não encontrado"
        read -p "Tentar instalação automática? (s/N): " -n 1 install_choice
        echo
        
        if [[ "$install_choice" =~ ^[sS]$ ]]; then
            if install_fzf; then
                echo "✅ FZF instalado!"
                sleep 0.1
                
                # Verificar se funciona
                if ! command -v fzf &> /dev/null; then
                    echo "⚠️  Reinicie o terminal ou execute: source ~/.bashrc"
                    read -p "Pressione Enter para continuar..." </dev/tty
                fi
            else
                echo "❌ Falha na instalação. Instale FZF manualmente e execute novamente."
                exit 1
            fi
        else
            echo "❌ FZF é obrigatório para funcionamento"
            echo "📦 Execute: sudo apt install fzf"
            exit 1
        fi
    fi
}

pause() {
    echo
    read -p "Pressione Enter para continuar..." </dev/tty
}

confirm() {
    local message="$1"
    read -p "$message (s/N): " -n 1 response </dev/tty
    echo
    [[ "$response" =~ ^[sS]$ ]]
}

clear_screen() {
    clear
    echo "UPCODE v$CURRENT_VERSION - Sistema de Upload"  # Modificado para mostrar versão
    echo "═════════════════════════════"
    echo
}


normalize_path() {
    local path="$1"
    
    # Primeiro remove todos os escapes
    path="${path//\\/\/}"
    
    # Remove barras duplicadas
    while [[ "$path" =~ // ]]; do
        path="${path//\/\//\/}"
    done
    
    # Remove barra inicial e final
    path="${path#/}"
    path="${path%/}"
    
    echo "$path"
}



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
    clear_screen
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
    # sleep 3
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


# Corrigir a função load_user_folders para incluir a correção automática simples
load_user_folders() {
    user_folders=()
    
    # Tentar carregar do arquivo primeiro
    if [[ -f "$USER_FOLDERS_FILE" ]]; then
        while IFS= read -r folder; do
            [[ -n "$folder" ]] && user_folders+=("$folder")
        done < "$USER_FOLDERS_FILE"
    fi
    
    # SE NÃO TEM PASTAS, recarregar via login
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
    
    # echo "🔍 Debug load_user_folders - Pastas carregadas: ${#user_folders[@]}"
    printf '   📂 "%s"\n' "${user_folders[@]}"
}

#===========================================
# NAVEGAÇÃO REMOTA (SERVIDOR)
#===========================================


server_browser() {
    local current_path=""
    
    while true; do
        local token=""
        if [[ -f "$TOKEN_FILE" ]]; then
            token=$(cat "$TOKEN_FILE")
        fi
        
        if [[ -z "$token" ]]; then
            echo "❌ Token não encontrado"
            pause
            return
        fi
        
        clear_screen
        echo "🌐 Navegação no Servidor"
        echo "========================"
        
        if [[ -z "$current_path" ]]; then
            echo "📁 Suas Pastas Disponíveis (${#user_folders[@]} pastas)"
        else
            echo "📁 Navegando em: $current_path"
        fi
        echo "─────────────────────────────────"
        echo
        
        # Arrays separados: um para exibição e outro para dados reais
        local display_items=()  # Para mostrar no FZF (com ícones)
        local data_items=()     # Para armazenar nomes reais (sem ícones)
        local item_types=()     # Para identificar tipo de item: ROOT_FOLDER, SUB_FOLDER, FILE
        
        # Opção de voltar se não estiver na raiz
        if [[ -n "$current_path" ]]; then
            display_items+=("🔙 Voltar")
            data_items+=("__VOLTAR__")
            item_types+=("CONTROL")
        fi
        
        if [[ -z "$current_path" ]]; then
            # Mostrar pastas do usuário (raiz)
            load_user_folders


            # echo "🔍 DEBUG - Pastas RAIZ do usuário:"     # REMOVER
            # printf '   📂 ROOT: "%s"\n' "${user_folders[@]}"  # REMOVER
            # echo    


            if [[ ${#user_folders[@]} -gt 0 ]]; then
                for folder in "${user_folders[@]}"; do
                    # Preservar formato original, mas limpar apenas para exibição
                    local clean_display="${folder//\\\//\/}"
                    
                    display_items+=("🏠 $clean_display")
                    data_items+=("$folder")  # Manter formato EXATO original
                    item_types+=("ROOT_FOLDER")
                done
            else
                display_items+=("❌ Nenhuma pasta disponível")
                data_items+=("__ERRO__")
                item_types+=("CONTROL")
            fi
        else
            # echo "🔧 DEBUG: Navegando em: '$current_path'"
            
            local response=$(curl -s -X POST "$CONFIG_URL" \
                -H "Authorization: Bearer $token" \
                -d "action=list" \
                -d "path=$current_path")

            # echo "📥 RESPOSTA DA API:"
            # echo "$response" | head -20
            # echo
            
            if echo "$response" | grep -q '"success":[[:space:]]*true'; then
                local items_found=false
                
                # Extrair itens da resposta
                while IFS= read -r line; do
                    if [[ "$line" =~ \"name\":[[:space:]]*\"([^\"]+)\" ]]; then
                        local clean_name="${BASH_REMATCH[1]}"
                        if [[ -n "$clean_name" ]]; then
                            items_found=true
                            
                            # Verificar se é diretório
                            if echo "$response" | grep -A3 -B3 "\"name\":[[:space:]]*\"$clean_name\"" | grep -q '"type":[[:space:]]*"directory"'; then
                                display_items+=("📂 $clean_name")
                                data_items+=("$clean_name")
                                item_types+=("SUB_FOLDER")
                            else
                                # É arquivo
                                local size_info=$(echo "$response" | grep -A5 -B5 "\"name\":[[:space:]]*\"$clean_name\"" | grep -o '"size":[[:space:]]*[0-9]*' | head -1)
                                if [[ -n "$size_info" ]]; then
                                    local size=$(echo "$size_info" | sed 's/.*"size":[[:space:]]*\([0-9]*\).*/\1/')
                                    if [[ "$size" -gt 1048576 ]]; then
                                        display_items+=("📄 $clean_name ($(( size / 1048576 ))MB)")
                                    elif [[ "$size" -gt 1024 ]]; then
                                        display_items+=("📄 $clean_name ($(( size / 1024 ))KB)")
                                    elif [[ "$size" -gt 0 ]]; then
                                        display_items+=("📄 $clean_name (${size}B)")
                                    else
                                        display_items+=("📄 $clean_name")
                                    fi
                                else
                                    display_items+=("📄 $clean_name")
                                fi
                                data_items+=("$clean_name")
                                item_types+=("FILE")
                            fi
                        fi
                    fi
                done <<< "$response"
                
                if [[ "$items_found" == "false" ]]; then
                    display_items+=("📁 Pasta vazia")
                    data_items+=("__VAZIO__")
                    item_types+=("CONTROL")
                fi
            else
                local error_msg=$(echo "$response" | grep -o '"message":[[:space:]]*"[^"]*"' | sed 's/.*"message":[[:space:]]*"\([^"]*\)".*/\1/')
                display_items+=("❌ Erro: ${error_msg:-"Falha na requisição"}")
                data_items+=("__ERRO__")
                item_types+=("CONTROL")
            fi
        fi
        
        # Opções de controle
        display_items+=("")
        data_items+=("__SEPARADOR__")
        item_types+=("CONTROL")
        
        if [[ -n "$current_path" ]]; then
            display_items+=("🔄 Sincronizar com pasta local")
            data_items+=("__SYNC__")
            item_types+=("CONTROL")
        fi
        
        display_items+=("🔄 Atualizar")
        data_items+=("__ATUALIZAR__")
        item_types+=("CONTROL")
        
        if [[ -n "$current_path" ]]; then
            display_items+=("🏠 Voltar às Pastas Disponíveis")
            data_items+=("__HOME__")
            item_types+=("CONTROL")
        fi
        
        #display_items+=("🔍 Navegar por Texto")
        data_items+=("__TEXTO__")
        item_types+=("CONTROL")
        
        display_items+=("🔙 Voltar")
        data_items+=("__SAIR__")
        item_types+=("CONTROL")
        
        # Mostrar no FZF
        local choice=$(printf '%s\n' "${display_items[@]}" | \
            fzf --prompt="$(if [[ -z "$current_path" ]]; then echo "Pastas > "; else echo "$(basename "$current_path") > "; fi)" \
                --header="Navegação no servidor" \
                --height=20)
        
        [[ -z "$choice" ]] && return
        
        # Encontrar o índice da escolha
        local selected_index=-1
        for i in "${!display_items[@]}"; do
            if [[ "${display_items[$i]}" == "$choice" ]]; then
                selected_index=$i
                break
            fi
        done
        
        if [[ $selected_index -eq -1 ]]; then
            continue
        fi
        
        local real_name="${data_items[$selected_index]}"
        local item_type="${item_types[$selected_index]}"
        
        #echo "🔧 DEBUG: Escolha='$choice', Nome='$real_name', Tipo='$item_type'"
        
        # Processar escolha
        case "$real_name" in
            "__VOLTAR__")
                if [[ "$current_path" == */* ]]; then
                    current_path="${current_path%/*}"
                    #echo "🔧 DEBUG: Voltando para: '$current_path'"
                else
                    current_path=""
                    #echo "🔧 DEBUG: Voltando à raiz"
                fi
                ;;
            "__HOME__")
                current_path=""
                ;;
            "__TEXTO__")
                echo
                read -p "Caminho exato: " user_path </dev/tty
                if [[ -n "$user_path" ]]; then
                    current_path="$user_path"
                fi
                ;;
            "__SYNC__")
                start_server_sync "$current_path"
                ;;
            "__ATUALIZAR__"|"__SEPARADOR__")
                # Continua loop
                ;;
            "__SAIR__")
                return
                ;;
            "__VAZIO__"|"__ERRO__")
                # Ignorar
                ;;
            *)
                case "$item_type" in
                    "ROOT_FOLDER")
                        current_path="$real_name"
                        echo "🔧 DEBUG: Entrando na pasta raiz: '$current_path'"
                        ;;
                    "SUB_FOLDER")
                        if [[ -n "$current_path" ]]; then
                            current_path="$current_path/$real_name"
                        else
                            current_path="$real_name"
                        fi
                        echo "🔧 DEBUG: Entrando na subpasta: '$current_path'"
                        ;;
                    "FILE")
                        echo "📄 Arquivo: $real_name"
                        echo "📁 Em: $current_path"
                        pause
                        ;;
                esac
                ;;
        esac
    done
}


extract_user_info() {
    local response="$1"
    
    echo "🔍 Debug - Extraindo dados do usuário..."
    
    # Extrair dados do usuário do JSON
    USER_DISPLAY_NAME=$(echo "$response" | grep -o '"user_display_name":[[:space:]]*"[^"]*"' | sed 's/.*"user_display_name":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_NICENAME=$(echo "$response" | grep -o '"user_nicename":[[:space:]]*"[^"]*"' | sed 's/.*"user_nicename":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_EMAIL=$(echo "$response" | grep -o '"user_email":[[:space:]]*"[^"]*"' | sed 's/.*"user_email":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_TYPE=$(echo "$response" | grep -o '"user_type":[[:space:]]*"[^"]*"' | sed 's/.*"user_type":[[:space:]]*"\([^"]*\)".*/\1/')
    USER_CAN_DELETE=$(echo "$response" | grep -o '"can_delete":[[:space:]]*[^,}]*' | sed 's/.*"can_delete":[[:space:]]*\([^,}]*\).*/\1/')
    
    # Salvar no arquivo
    cat > "$USER_INFO_FILE" << EOF
USER_DISPLAY_NAME="$USER_DISPLAY_NAME"
USER_NICENAME="$USER_NICENAME"  
USER_EMAIL="$USER_EMAIL"
USER_TYPE="$USER_TYPE"
USER_CAN_DELETE="$USER_CAN_DELETE"
EOF
    chmod 600 "$USER_INFO_FILE"
    
    echo "👤 Dados do usuário extraídos:"
    echo "   Nome: $USER_DISPLAY_NAME"
    echo "   Login: $USER_NICENAME"
    echo "   Email: $USER_EMAIL"
    echo "   Tipo: $USER_TYPE"
    echo "   Pode deletar: $USER_CAN_DELETE"
}

confirm_delete_option() {
    local upload_type="$1"  # "arquivo" ou "pasta"
    local target_folder="${2:-}"  # pasta específica (opcional)
    
    # Se folder específica foi fornecida, verificar permissões dela
    if [[ -n "$target_folder" ]]; then
        if can_delete_in_folder "$target_folder"; then
            echo
            echo "🗑️ OPÇÃO DE EXCLUSÃO DISPONÍVEL PARA ESTA PASTA"
            echo "═════════════════════════════════════════════"
            echo "Você tem permissão para deletar arquivos nesta pasta antes do upload."
            echo "📁 Pasta: $target_folder"
        else
            echo
            echo "❌ SEM PERMISSÃO DE EXCLUSÃO PARA ESTA PASTA"
            echo "═══════════════════════════════════════════"
            echo "📁 Pasta: $target_folder"
            echo "ℹ️ Upload será feito SEM exclusão (arquivos serão adicionados/substituídos)"
            return 1
        fi
    elif [[ "$USER_CAN_DELETE" == "true" ]]; then
        echo
        echo "🗑️ OPÇÃO DE EXCLUSÃO DISPONÍVEL"
        echo "══════════════════════════════════"
        echo "Você tem permissão para deletar arquivos no destino antes do upload."
    else
        return 1  # Sem permissões gerais
    fi
    
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
    
    # Método atualizado para extrair as CHAVES do objeto folders (não mais array)
    # Formato novo: "folders": { "pasta1/": true, "pasta2/": false }
    local folders_section=$(echo "$response" | sed -n '/"folders":/,/}/p')
    
    echo "🔍 Debug - Seção folders:"
    echo "$folders_section"
    
    # Limpar arquivo anterior
    > "$USER_FOLDERS_FILE"
    
    # Extrair apenas as CHAVES do objeto folders (ignorar valores true/false)
    # Procurar por padrão: "chave": valor (onde valor pode ser true/false)
    echo "$folders_section" | grep -o '"[^"]*"[[:space:]]*:' | sed 's/"//g; s/[[:space:]]*://g' | while read -r folder; do
        # Filtrar apenas linhas que não são palavras-chave JSON
        if [[ "$folder" != "folders" && -n "$folder" && "$folder" != "true" && "$folder" != "false" ]]; then
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
    
    # Extrair também as permissões de exclusão por pasta
    extract_folder_permissions "$response"
}

# Nova função para extrair permissões de exclusão por pasta
extract_folder_permissions() {
    local response="$1"
    
    echo "🔍 Debug - Extraindo permissões de pasta..."
    
    # Limpar arquivo de permissões anterior
    > "$USER_FOLDER_PERMISSIONS_FILE"
    
    # Extrair o objeto folders completo
    local folders_section=$(echo "$response" | sed -n '/"folders":/,/}/p')
    
    # Extrair pares chave:valor para permissões
    echo "$folders_section" | grep -o '"[^"]*"[[:space:]]*:[[:space:]]*[a-z]*' | while read -r line; do
        # Separar chave e valor
        local folder=$(echo "$line" | sed 's/"//g; s/[[:space:]]*:.*//g')
        local permission=$(echo "$line" | sed 's/.*:[[:space:]]*//g')
        
        # Filtrar palavras-chave
        if [[ "$folder" != "folders" && -n "$folder" && "$permission" =~ ^(true|false)$ ]]; then
            echo "$folder:$permission" >> "$USER_FOLDER_PERMISSIONS_FILE"
        fi
    done
    
    echo "🔒 Permissões de pasta extraídas"
}

# Função para verificar se usuário pode deletar em uma pasta específica
can_delete_in_folder() {
    local folder="$1"
    
    if [[ ! -f "$USER_FOLDER_PERMISSIONS_FILE" ]]; then
        return 1  # Sem permissões conhecidas, não permitir exclusão
    fi
    
    local permission=$(grep "^$folder:" "$USER_FOLDER_PERMISSIONS_FILE" | cut -d':' -f2)
    [[ "$permission" == "true" ]]
}

load_user_folders() {
    user_folders=()
    if [[ -f "$USER_FOLDERS_FILE" ]]; then
        while IFS= read -r folder; do
            [[ -n "$folder" ]] && user_folders+=("$folder")
        done < "$USER_FOLDERS_FILE"
    fi
    
    
    # echo "🔍 Debug load_user_folders - Pastas carregadas: ${#user_folders[@]}"
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
        rm -f "$TOKEN_FILE" "$USER_FOLDERS_FILE" "$USER_INFO_FILE" "$USER_FOLDER_PERMISSIONS_FILE"
        
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

#===========================================
# NAVEGAÇÃO DE ARQUIVOS
#===========================================
file_browser() {
    local current_dir="${1:-$HOME}"
    
    if [[ -d "/mnt/c/Users" && "$current_dir" == "$HOME" ]]; then
        current_dir="/mnt/c/Users"
    elif [[ ! -d "$current_dir" ]]; then
        current_dir="$HOME"
    fi
    
    while true; do
        clear_screen
        echo "📁 Navegador: $(basename "$current_dir")"
        echo "📂 Caminho: $current_dir"
        echo "─────────────────────────────────"
        
        local items=()
        
        if [[ "$current_dir" != "/" && "$current_dir" != "/mnt/c" ]]; then
            items+=(".. [🔙 Voltar]")
        fi
        
        items+=("UPLOAD_FOLDER_AS_STRUCTURE|| 1. ENVIAR PASTA COMPLETA: $(basename "$current_dir")")
        items+=("UPLOAD_CURRENT|| 2. ENVIAR CONTEÚDO DA PASTA: $(basename "$current_dir")")
        items+=("SYNC_FOLDER|| 3. 🔄 SINCRONIZAR ESTA PASTA: $(basename "$current_dir")")
        items+=("HISTORY|| 4. VER HISTÓRICO")
        items+=("")
        
        local dir_count=0
        local file_count=0
        
        if [[ -r "$current_dir" ]]; then
            while IFS= read -r item; do
                [[ -z "$item" ]] && continue
                local full_path="$current_dir/$item"
                if [[ -d "$full_path" ]]; then
                    items+=("DIR|$full_path|📂 $item/")
                    ((dir_count++))
                fi
            done < <(ls -1 "$current_dir" 2>/dev/null | head -30)
            
            while IFS= read -r item; do
                [[ -z "$item" ]] && continue
                local full_path="$current_dir/$item"
                if [[ -f "$full_path" ]]; then
                    local size=$(du -sh "$full_path" 2>/dev/null | cut -f1 || echo "?")
                    items+=("FILE|$full_path|📄 $item ($size)")
                    ((file_count++))
                fi
            done < <(ls -1 "$current_dir" 2>/dev/null | head -20)
        fi
        
        items+=("")
        items+=("BACK||🔙 Voltar ao menu principal")
        
        echo "📊 Encontrados: $dir_count pastas, $file_count arquivos"

        local choice=$(printf '%s\n' "${items[@]}" | \
            sed 's/^[^|]*|[^|]*|//' | \
            fzf --prompt="📁 $(basename "$current_dir") > " \
                --header="Enter = Navegar/Selecionar | Esc = Voltar" \
                --height=25)
        
        [[ -z "$choice" ]] && return
        
        local selected_line=""
        for item in "${items[@]}"; do
            if [[ "$item" == *"|$choice" ]]; then
                selected_line="$item"
                break
            fi
        done
        
        local action=$(echo "$selected_line" | cut -d'|' -f1)
        local path=$(echo "$selected_line" | cut -d'|' -f2)
        
        case "$action" in
            "DIR")
                current_dir="$path"
                ;;
            "FILE")
                upload_single_file "$path"
                ;;
            "UPLOAD_FOLDER_AS_STRUCTURE")
                upload_folder_as_complete_structure "$current_dir"
                ;;
            "UPLOAD_CURRENT")
                upload_folder_content_only "$current_dir"
                ;;
            "SYNC_FOLDER")
                # ATALHO: Apenas pegar caminho e chamar função principal
                echo "🔄 Preparando sincronização para: $(basename "$current_dir")"
                echo "📁 Caminho capturado: $current_dir"
                sleep 1
                
                # Selecionar pasta servidor
                if [[ ${#user_folders[@]} -gt 0 ]]; then
                    echo "📁 Pastas disponíveis no servidor:"
                    printf '   📂 %s\n' "${user_folders[@]}"
                    echo
                    
                    local server_folder=$(printf '%s\n' "${user_folders[@]}" | \
                        fzf --prompt="Pasta destino no servidor > " \
                            --header="Selecione onde sincronizar")
                    
                    if [[ -n "$server_folder" ]]; then
                        # Chamar função principal passando os caminhos
                        start_server_sync_with_local_path "$current_dir" "$server_folder"
                    fi
                else
                    echo "❌ Nenhuma pasta disponível no servidor"
                    pause
                fi
                ;;
            "HISTORY")
                show_upload_history
                ;;
            "BACK")
                return
                ;;
            *)
                if [[ "$choice" == *"[🔙 Voltar]" ]]; then
                    current_dir=$(dirname "$current_dir")
                elif [[ "$choice" == *"📂"* && "$choice" == *"/" ]]; then
                    local folder_name=$(echo "$choice" | sed 's/📂 //' | sed 's/\/$//')
                    current_dir="$current_dir/$folder_name"
                fi
                ;;
        esac
    done
}

# ...existing code... (SUBSTITUIR a função start_server_sync_with_local_path)

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
    if confirm_delete_option "pasta completa"; then
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
    if confirm_delete_option "conteúdo"; then
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

#===========================================
# UPLOAD DE ARQUIVOS E PASTAS COMPLETAS
#===========================================


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
    
    echo "🔍 Debug - Pastas para seleção:"
    printf '   📂 "%s"\n' "${user_folders[@]}"
    echo
    
    local folder=$(printf '%s\n' "${user_folders[@]}" | \
        fzf --prompt="Pasta de destino > " \
            --header="Selecione onde enviar o arquivo" \
            --height=$((${#user_folders[@]} + 5)))
    
    [[ -z "$folder" ]] && return
    
    # Verificar opção de exclusão
    local with_delete=false
    if confirm_delete_option "arquivo" "$folder"; then
        with_delete=true
    fi
    
    # echo
    # echo "📋 Resumo:"
    # echo "  📄 Arquivo: $(basename "$file")"
    # echo "  📁 Destino: $folder"
    # if [[ "$with_delete" == "true" ]]; then
    #     echo "  🗑️ Exclusão prévia: SIM"
    # else
    #     echo "  🗑️ Exclusão prévia: NÃO"
    # fi
    
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
        echo "📄 Arquivo local: $(basename "$arquivo")"
        echo "📁 Caminho relativo: $rel_path"
        echo "🎯 Destino normalizado: $dest_path"
        echo "💾 Tamanho: $(du -sh "$arquivo" 2>/dev/null | cut -f1 || echo "N/A")"
        
        
        local corrected_file="$arquivo"
        if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
            if [[ "$arquivo" =~ ^/c/ ]]; then
                corrected_file=$(echo "$arquivo" | sed 's|^/c|C:|')
                echo "🔧 Caminho corrigido para Windows: $corrected_file"
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
        echo "🔍 DEBUG - Verificação do delete:"
        echo "  with_delete_param: '$with_delete_param'"
        echo "  delete_applied: '$delete_applied'"
        echo "  Vai aplicar delete? $([[ "$with_delete_param" == "true" && "$delete_applied" == "false" ]] && echo "SIM" || echo "NÃO")"
        
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
        echo "🔧 DEBUG - Array completo do curl_cmd:"
        for i in "${!curl_cmd[@]}"; do
            if [[ "${curl_cmd[$i]}" == *"Authorization: Bearer"* ]]; then
                echo "  [$i]: 'Authorization: Bearer ${token:0:10}...***'"
            elif [[ "${curl_cmd[$i]}" == *"@"* ]]; then
                echo "  [$i]: 'arquivo[]=@$(basename "${curl_cmd[$i]#*@}")'"
            else
                echo "  [$i]: '${curl_cmd[$i]}'"
            fi
        done
        echo
        
        # Executar upload
        echo "⏳ Executando upload..."
        local start_time=$(date +%s)
        local response=$("${curl_cmd[@]}" 2>&1)
        local curl_exit=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # NOVO DEBUG: Verificar se a API realmente recebeu o with_delete
        echo "🔍 TESTE DEBUG - Resposta sobre delete:"
        if echo "$response" | grep -i -E "(delet|remov|clean|clear)" | head -3; then
            echo "   ✅ API mencionou operação de delete"
        else
            echo "   ❌ API NÃO mencionou delete na resposta"
        fi
        
        ((upload_count++))
        
        echo "⌛ Tempo de upload: ${duration}s"
        echo "🔍 Exit code curl: $curl_exit"
        
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
    echo "🔧 COMANDO CURL DETALHADO:"
    echo "─────────────────────────"
    echo "  📡 URL: $CONFIG_URL"
    echo "  🔑 Token: ${token:0:20}..."
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
    echo
    echo "🔍 PARÂMETROS ENVIADOS:"
    echo "  -H \"Authorization: Bearer ${token:0:10}...***\""
    echo "  -F \"arquivo[]=@$filename\""
    echo "  -F \"pasta=$folder\""
    if [[ "$with_delete" == "true" ]]; then
        echo "  -F \"with_delete=true\""
    fi
    echo
    
    # Executar upload
    echo "⏳ Executando upload..."
    local start_time=$(date +%s)
    local response=$("${curl_cmd[@]}" 2>&1)
    local curl_exit=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "⌛ Tempo de execução: ${duration}s"
    echo "🔍 Exit code: $curl_exit"
    
    # Análise detalhada da resposta
    echo
    echo "📋 ANÁLISE DA RESPOSTA:"
    echo "─────────────────────"
    
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
        echo "✅ Resposta é JSON válido"
        
        # Extrair informações do JSON
        local success_status=$(echo "$response" | grep -o '"success":[[:space:]]*[^,}]*' | sed 's/.*"success":[[:space:]]*\([^,}]*\).*/\1/')
        local message=$(echo "$response" | grep -o '"message":[[:space:]]*"[^"]*"' | sed 's/.*"message":[[:space:]]*"\([^"]*\)".*/\1/')
        
        echo "   🎯 Status: ${success_status:-"não encontrado"}"
        echo "   💬 Mensagem: ${message:-"não encontrada"}"
        
        # Mostrar resposta completa para debug
        echo
        echo "📄 RESPOSTA COMPLETA:"
        echo "─────────────────────"
        echo "$response" | head -20
        
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

# Adiciona entrada ao histórico de uploads
add_to_history() {
    local item="$1"
    local item_type="$2"
    local destination="$3"
    
    touch "$HISTORY_FILE"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local history_entry="$item_type|$item|$destination|$timestamp"
    
    # Remover entrada anterior se existir
    grep -v "^[^|]*|$item|" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null || true
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE" 2>/dev/null || true
    
    # Adicionar no topo
    echo "$history_entry" >> "$HISTORY_FILE"
    
    # Manter apenas os últimos 20
    tail -n 20 "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

#===========================================
# SINCRONIZAÇÃO
#===========================================


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

#===========================================
# MENU PRINCIPAL
#===========================================

main_menu() {
    while true; do
        clear_screen
        
        # Carregar dados do usuário para exibição
        load_user_info
        
        echo "📡 Sistema ativo e conectado"
        if [[ -n "$USER_DISPLAY_NAME" ]]; then
            echo "👤 Logado como: $USER_DISPLAY_NAME ($USER_NICENAME)"
            echo "📧 Email: $USER_EMAIL |  Tipo: $USER_TYPE"
        else
            echo "👤 Status: Não logado"
        fi
        echo
        
        # Verificar se há histórico
        local history_count=0
        if [[ -f "$HISTORY_FILE" ]]; then
            history_count=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
        fi
        

        # Mostrar informações de status
        echo "📊 STATUS DO SISTEMA:"
        echo "   📦 Versão: $CURRENT_VERSION"
        echo "   📝 Histórico: $history_count itens"
        if [[ ${#user_folders[@]} -gt 0 ]]; then
            echo "   📁 Pastas disponíveis: ${#user_folders[@]}"
        fi
        echo
        
        # Criar opções do menu
        local menu_options=(
            "browser|📁 Navegador de Arquivos"
            "quick|⚡ Upload Rápido (último item)"
            "server|🌐 Ver Pastas Disponíveis"
            #"test_paths|🧪 Testar Formatos de Caminho"
            "history|📝 Histórico ($history_count itens)"
            "token|🔄 Renovar Token"
            "clean|🧹 Limpar Dados"
            "exit|❌ Sair"
        )
        
        
        # Mostrar menu
        local choice=$(printf '%s\n' "${menu_options[@]}" | \
            sed 's/^[^|]*|//' | \
            fzf --prompt="UPCODE v$CURRENT_VERSION  | $USER_DISPLAY_NAME > " \
                --header="Sistema de Upload de Arquivos - Selecione uma opção" \
                --preview-window=hidden)
        
        # Encontrar a ação correspondente
        for option in "${menu_options[@]}"; do
            if [[ "$option" == *"|$choice" ]]; then
                local action=$(echo "$option" | cut -d'|' -f1)
                case "$action" in
                    "browser") file_browser ;;
                    "server") server_browser ;;
                    "quick") quick_upload ;;
                    "history") show_upload_history ;;
                    "token") renew_token ;;
                    "clean") clean_data ;;
                    #"test_paths") test_path_formats ;; 
                    "exit") clear; exit 0 ;;
                esac
                break
            fi
        done
        
        
        # Se não encontrou correspondência e choice está vazio, sair
        [[ -z "$choice" ]] && { clear; exit 0; }
    done
}

clean_data() {
    while true; do
        clear_screen
        echo "🧹 Limpar Dados"
        echo "──────────────"
        echo
        
        if [[ -n "$USER_DISPLAY_NAME" ]]; then
            echo "👤 Usuário atual: $USER_DISPLAY_NAME ($USER_NICENAME)"
            echo
        fi
        
        local clean_options=(
            "back|🔙 Voltar"
            "token|🔑 Limpar Token (força novo login)"
            "history|📝 Limpar Histórico de uploads"
            "sync|🔄 Limpar Configuração de Sincronização"
            "folders|📁 Limpar Cache de Pastas"
            "userinfo|👤 Limpar Dados do Usuário"
            "all|🗑️ Limpar TUDO (reset completo)"
        )
        
        local choice=$(printf '%s\n' "${clean_options[@]}" | \
            sed 's/^[^|]*|//' | \
            fzf --prompt="Limpar Dados > " \
                --height=12)
        
        [[ -z "$choice" ]] && return
        
        for option in "${clean_options[@]}"; do
            if [[ "$option" == *"|$choice" ]]; then
                local action=$(echo "$option" | cut -d'|' -f1)
                
                case "$action" in
                    "token")
                        if confirm "⚠️ Limpar token? (forçará novo login)"; then
                            rm -f "$TOKEN_FILE"
                            echo "✅ Token removido!"
                            sleep 0.1
                            
                            echo "🔄 Novo login necessário..."
                            # Forçar novo login imediatamente
                            do_login
                            return  # Voltar ao menu principal após login
                        fi
                        ;;
                    "history")
                        if confirm "Limpar histórico de uploads?"; then
                            rm -f "$HISTORY_FILE"
                            echo "✅ Histórico limpo!"
                            sleep 0.1
                        fi
                        ;;
                    "folders")
                        if confirm "Limpar cache de pastas?"; then
                            rm -f "$USER_FOLDERS_FILE"
                            user_folders=()
                            echo "✅ Cache de pastas limpo!"
                            sleep 0.1
                        fi
                        ;;
                    "userinfo")
                        if confirm "Limpar dados do usuário?"; then
                            rm -f "$USER_INFO_FILE"
                            USER_DISPLAY_NAME=""
                            USER_NICENAME=""
                            USER_EMAIL=""
                            USER_TYPE=""
                            echo "✅ Dados do usuário limpos!"
                            sleep 0.1
                        fi
                        ;;
                    "all")
                        if confirm "⚠️ LIMPAR TUDO? (reset completo - forçará novo login)"; then
                            echo "🧹 Limpando todos os dados..."
                            
                            # Parar sincronização
                            if is_sync_running; then
                                echo "⏹️ Parando sincronização..."
                                stop_sync
                            fi
                            
                            # Remover todos os arquivos
                            rm -f "$TOKEN_FILE" "$HISTORY_FILE" "$SYNC_CONFIG_FILE" "$SYNC_CACHE_FILE" "$SYNC_LOG_FILE" "$USER_FOLDERS_FILE" "$USER_INFO_FILE"
                            
                            # Limpar variáveis
                            USER_DISPLAY_NAME=""
                            USER_NICENAME=""
                            USER_EMAIL=""
                            USER_TYPE=""
                            user_folders=()
                            
                            echo "✅ Todos os dados limpos!"
                            sleep 0.1
                            
                            echo "🔄 Novo login necessário..."
                            # Forçar novo login imediatamente
                            do_login
                            return  # Voltar ao menu principal após login
                        fi
                        ;;
                    "back")
                        return
                        ;;
                esac
                break
            fi
        done
    done
}


#===========================================
# FUNÇÃO PRINCIPAL (modificada apenas para adicionar verificação)
#===========================================


show_progress() {
    local message="$1"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while [ $i -lt 20 ]; do
        printf "\r%s %s" "$message" "${chars:$((i % ${#chars})):1}"
        sleep 0.1
        ((i++))
    done
    printf "\r%s ✅\n" "$message"
}

#===========================================
# INÍCIO DIRETO DO PROGRAMA
#===========================================

show_banner
check_dependencies

# Verificar token APENAS UMA VEZ no início
if ! check_token; then
    echo "🔍 Token não encontrado ou inválido - fazendo login..."
    do_login
else
    echo "✅ Token válido encontrado"
    load_user_folders
    echo "📁 Pastas carregadas: ${#user_folders[@]}"
fi

main_menu