#!/bin/bash
#===========================================
# CONFIGURAÇÕES
#===========================================
CURRENT_VERSION="1.0.0"
CONFIG_URL="https://db33.dev.dinabox.net/upcode3/upcode.php" 
AUTH_URL="https://db33.dev.dinabox.net/upcode3/upcode.php"  
TOKEN_FILE="$HOME/.upcode_token"
HISTORY_FILE="$HOME/.upcode_history"
SYNC_CONFIG_FILE="$HOME/.upcode_sync_config"
SYNC_CACHE_FILE="$HOME/.upcode_sync_cache"
SYNC_PID_FILE="$HOME/.upcode_sync_pid"
SYNC_LOG_FILE="$HOME/.upcode_sync_debug.log"
USER_FOLDERS_FILE="$HOME/.upcode_user_folders" 
USER_INFO_FILE="$HOME/.upcode_user_info" 
USER_CAN_DELETE=""

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
    sleep 2
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
                sleep 1
                
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

sync_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$SYNC_LOG_FILE"
    
    # Manter apenas as últimas 50 linhas do log
    if [[ -f "$SYNC_LOG_FILE" ]]; then
        tail -n 50 "$SYNC_LOG_FILE" > "$SYNC_LOG_FILE.tmp"
        mv "$SYNC_LOG_FILE.tmp" "$SYNC_LOG_FILE"
    fi
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
            
            if [[ ${#user_folders[@]} -gt 0 ]]; then
                for folder in "${user_folders[@]}"; do
                    display_items+=("📂 $folder")
                    data_items+=("$folder")
                    item_types+=("ROOT_FOLDER")  # Pasta raiz do usuário
                done
            else
                display_items+=("❌ Nenhuma pasta disponível")
                data_items+=("__ERRO__")
                item_types+=("CONTROL")
            fi
        else
            # Explorar conteúdo de uma pasta específica
            echo "🔧 DEBUG: Caminho enviado para API: '$current_path'"
            
            # CORREÇÃO: Limpar e normalizar o path antes de enviar
            local clean_path="$current_path"
            # Remover barras duplicadas
            clean_path=$(echo "$clean_path" | sed 's|/\+|/|g')
            # Remover barra inicial se existir
            clean_path="${clean_path#/}"
            # Remover barra final se existir
            clean_path="${clean_path%/}"
            
            echo "🔧 DEBUG: Path normalizado: '$clean_path'"
            
            local response=$(curl -s -X POST "$CONFIG_URL" \
                -H "Authorization: Bearer $token" \
                -d "action=list" \
                -d "path=$clean_path")
            
            echo "🔍 DEBUG: Resposta recebida: $(echo "$response" | head -c 200)..."
            
            if echo "$response" | grep -q '"success":[[:space:]]*true'; then
                local items_found=false
                
                # Extrair apenas os nomes dos arquivos/pastas
                while IFS= read -r line; do
                    if [[ "$line" =~ \"name\":[[:space:]]*\"([^\"]+)\" ]]; then
                        local clean_name="${BASH_REMATCH[1]}"
                        if [[ -n "$clean_name" ]]; then
                            items_found=true
                            
                            # Verificar se é diretório
                            if echo "$response" | grep -A3 -B3 "\"name\":[[:space:]]*\"$clean_name\"" | grep -q '"type":[[:space:]]*"directory"'; then
                                display_items+=("📂 $clean_name")
                                data_items+=("$clean_name")
                                item_types+=("SUB_FOLDER")  # Subpasta dentro da pasta atual
                            else
                                # É arquivo - tentar extrair tamanho
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
        
        # Opções de controle - adicionar separador se houver itens
        if [[ ${#display_items[@]} -gt 0 ]]; then
            # Adicionar pastas raiz disponíveis quando não estamos na raiz
            if [[ -n "$current_path" ]]; then
                display_items+=("")
                data_items+=("__SEPARADOR__")
                item_types+=("CONTROL")
                
                display_items+=("--- [📁 NAVEGAR PARA OUTRAS PASTAS] ---")
                data_items+=("__HEADER__")
                item_types+=("CONTROL")
                
                # Mostrar outras pastas disponíveis para navegação rápida
                for folder in "${user_folders[@]}"; do
                    # Não mostrar a pasta atual
                    if [[ "$folder" != "${current_path%%/*}" ]]; then
                        display_items+=("🏠 $folder")
                        data_items+=("$folder")
                        item_types+=("ROOT_FOLDER")
                    fi
                done
            fi
        fi
        
        display_items+=("")
        data_items+=("__SEPARADOR__")
        item_types+=("CONTROL")
        
        display_items+=("🔄 Atualizar")
        data_items+=("__ATUALIZAR__")
        item_types+=("CONTROL")
        
        if [[ -n "$current_path" ]]; then
            display_items+=("🏠 Voltar às Pastas Disponíveis")
            data_items+=("__HOME__")
            item_types+=("CONTROL")
        fi
        
        display_items+=("🔍 Navegar por Texto")
        data_items+=("__TEXTO__")
        item_types+=("CONTROL")
        
        display_items+=("❌ Sair")
        data_items+=("__SAIR__")
        item_types+=("CONTROL")
        
        # Mostrar no FZF
        local choice=$(printf '%s\n' "${display_items[@]}" | \
            fzf --prompt="$(if [[ -z "$current_path" ]]; then echo "Pastas > "; else echo "$(basename "$current_path") > "; fi)" \
                --header="Navegação no servidor" \
                --height=20)
        
        [[ -z "$choice" ]] && return
        
        # Encontrar o índice da escolha para pegar o nome real e tipo
        local selected_index=-1
        for i in "${!display_items[@]}"; do
            if [[ "${display_items[$i]}" == "$choice" ]]; then
                selected_index=$i
                break
            fi
        done
        
        if [[ $selected_index -eq -1 ]]; then
            continue  # Escolha não encontrada, continua loop
        fi
        
        local real_name="${data_items[$selected_index]}"
        local item_type="${item_types[$selected_index]}"
        
        echo "🔧 DEBUG: Escolha='$choice', Nome='$real_name', Tipo='$item_type'"
        
        # Processar escolha baseada no nome real E tipo
        case "$real_name" in
            "__VOLTAR__")
                # Voltar um nível - controle correto de caminhos
                if [[ "$current_path" == */* ]]; then
                    current_path="${current_path%/*}"  # Remove último componente
                    if [[ -z "$current_path" ]]; then
                        current_path=""  # Se ficou vazio, vai para raiz
                    fi
                else
                    current_path=""  # Já estava no primeiro nível
                fi
                echo "🔧 DEBUG: Voltando para: '$current_path'"
                ;;
            "__HOME__")
                current_path=""
                echo "🔧 DEBUG: Voltando à raiz"
                ;;
            "__TEXTO__")
                echo
                read -p "Caminho (ex: fernando-teste/subpasta): " user_path </dev/tty
                if [[ -n "$user_path" ]]; then
                    # Limpar path do usuário
                    user_path="${user_path#/}"  # Remove barra inicial
                    user_path="${user_path%/}"  # Remove barra final
                    current_path="$user_path"
                    echo "🔧 DEBUG: Caminho manual definido: '$current_path'"
                fi
                ;;
            "__ATUALIZAR__"|"__SEPARADOR__"|"__HEADER__")
                # Apenas continua o loop
                ;;
            "__SAIR__")
                return
                ;;
            "__VAZIO__"|"__ERRO__")
                # Ignorar
                ;;
            *)
                # Navegação baseada no TIPO do item
                case "$item_type" in
                    "ROOT_FOLDER")
                        # Navegação para pasta raiz - RESETAR caminho
                        current_path="$real_name"
                        echo "🔧 DEBUG: Navegando para pasta raiz: '$current_path'"
                        ;;
                    "SUB_FOLDER")
                        # Navegação para subpasta - CONCATENAR ao caminho atual
                        if [[ -z "$current_path" ]]; then
                            current_path="$real_name"
                        else
                            current_path="$current_path/$real_name"
                        fi
                        echo "🔧 DEBUG: Navegando para subpasta: '$current_path'"
                        ;;
                    "FILE")
                        echo "📄 Arquivo selecionado: $real_name"
                        echo "📁 Localizado em: $current_path"
                        pause
                        ;;
                    *)
                        echo "⚠️ Tipo de item desconhecido: $item_type"
                        ;;
                esac
                ;;
        esac
    done
}

#===========================================
# AUTENTICAÇÃO
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
        
        sleep 3
        return 0
    else
        echo "❌ Falha na autenticação!"
        echo "🔍 Resposta do servidor:"
        echo "$response" | head -5
        pause
        exit 1
    fi
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
    
    if [[ "$USER_CAN_DELETE" == "true" ]]; then
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
    fi
    return 1  # Se não tem permissão, sempre false
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
        
        items+=("")
        items+=("UPLOAD_FOLDER_AS_STRUCTURE||📦 ENVIAR PASTA COMPLETA: $(basename "$current_dir")")
        items+=("UPLOAD_CURRENT||📤 ENVIAR CONTEÚDO DA PASTA: $(basename "$current_dir")")
        items+=("SYNC_CURRENT||🔄 SINCRONIZAR ESTA PASTA: $(basename "$current_dir")")
        items+=("")
        items+=("--- [📤 CONTEÚDO ATUAL] ---")
        
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
        items+=("HISTORY||📝 Ver histórico")
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
            "SYNC_CURRENT")
                setup_sync_for_folder "$current_dir"
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
    
    # # Verificar opção de exclusão
    # local with_delete=false
    # if confirm_delete_option "arquivo"; then
    #     with_delete=true
    # fi
    
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
    if confirm_delete_option "pasta"; then
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
    local with_delete="$4"
    
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
    if [[ "$with_delete" == "true" ]]; then
        echo "🗑️ COM exclusão prévia dos arquivos existentes"
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
 local dest_path="$rel_path"
        if [[ -n "$subpasta" ]]; then
            dest_path="$subpasta/$rel_path"
        fi
        
        # CORREÇÃO: Normalizar dest_path antes de enviar
        # Remover barras duplicadas
        dest_path=$(echo "$dest_path" | sed 's|/\+|/|g')
        # Remover barra inicial se existir
        dest_path="${dest_path#/}"
        # Remover barra final se existir  
        dest_path="${dest_path%/}"
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📤 ENVIANDO ARQUIVO $((upload_count + 1))/${#files_array[@]}"
        echo "📄 Arquivo local: $(basename "$arquivo")"
        echo "📁 Caminho relativo: $rel_path"
        echo "🎯 Destino normalizado: $dest_path"
        echo "💾 Tamanho: $(du -sh "$arquivo" 2>/dev/null | cut -f1 || echo "N/A")"
        
        # Corrigir caminho para curl (Windows/WSL)
        local corrected_file="$arquivo"
        if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
            if [[ "$arquivo" =~ ^/c/ ]]; then
                corrected_file=$(echo "$arquivo" | sed 's|^/c|C:|')
                echo "🔧 Caminho corrigido para Windows: $corrected_file"
            fi
        fi
        
        # Construir comando curl com path normalizado
        local curl_cmd=(
            curl -s -X POST "$CONFIG_URL"
            -H "Authorization: Bearer $token"
            -F "arquivo[]=@$corrected_file"
            -F "pasta=$pasta_destino"
        )
        
        # Adicionar path apenas se não estiver vazio
        if [[ -n "$dest_path" && "$dest_path" != "." ]]; then
            curl_cmd+=(-F "path=$dest_path")
        fi
        # Aplicar with_delete apenas no PRIMEIRO arquivo
        if [[ "$with_delete" == "true" && "$delete_applied" == "false" ]]; then
            curl_cmd+=(-F "with_delete=true")
            delete_applied=true
            echo "🗑️ APLICANDO exclusão prévia neste primeiro envio"
        fi
        
        # Mostrar comando curl completo (mascarando token sensível)
        echo
        echo "🔧 COMANDO CURL EXECUTADO:"
        local masked_cmd=()
        for param in "${curl_cmd[@]}"; do
            if [[ "$param" == *"Authorization: Bearer"* ]]; then
                masked_cmd+=("Authorization: Bearer ${token:0:10}...***")
            elif [[ "$param" == *"@"* ]]; then
                masked_cmd+=("arquivo[]=@$(basename "${param#*@}")")
            else
                masked_cmd+=('"'"$param"'"')
            fi
        done
        printf '   %s \\\n' "${masked_cmd[@]}"
        echo
        
        # Executar upload com timeout
        echo "⏳ Executando upload..."
        local start_time=$(date +%s)
        local response=$("${curl_cmd[@]}" 2>&1)
        local curl_exit=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        ((upload_count++))
        
        echo "⌛ Tempo de upload: ${duration}s"
        echo "🔍 Exit code curl: $curl_exit"
        
        # Análise detalhada da resposta
        echo
        echo "📋 ANÁLISE DA RESPOSTA:"
        echo "─────────────────────────"
        
        if [[ $curl_exit -ne 0 ]]; then
            echo "❌ ERRO CURL (Exit Code: $curl_exit)"
            case $curl_exit in
                6) echo "   💥 Não conseguiu resolver o hostname" ;;
                7) echo "   🔌 Falha na conexão" ;;
                28) echo "   ⏰ Timeout da operação" ;;
                35) echo "   🔒 Erro SSL/TLS" ;;
                56) echo "   📡 Falha ao receber dados da rede" ;;
                *) echo "   ❓ Erro desconhecido" ;;
            esac
            echo "   📄 Resposta bruta: ${response:0:200}..."
            error_files+=("$(basename "$arquivo")")
            error_details+=("CURL_ERROR_$curl_exit: ${response:0:100}")
            ((error_count++))
            continue
        fi
        
        # Verificar se a resposta parece ser JSON
        if [[ "$response" =~ ^\{.*\}$ ]] || [[ "$response" =~ ^\[.*\]$ ]]; then
            echo "✅ Resposta é JSON válido"
            
            # Extrair informações específicas do JSON
            local success_status=$(echo "$response" | grep -o '"success":[[:space:]]*[^,}]*' | sed 's/.*"success":[[:space:]]*\([^,}]*\).*/\1/')
            local message=$(echo "$response" | grep -o '"message":[[:space:]]*"[^"]*"' | sed 's/.*"message":[[:space:]]*"\([^"]*\)".*/\1/')
            local requested_folder=$(echo "$response" | grep -o '"requested_folder":[[:space:]]*"[^"]*"' | sed 's/.*"requested_folder":[[:space:]]*"\([^"]*\)".*/\1/')
            
            echo "   🎯 Status success: ${success_status:-"não encontrado"}"
            echo "   💬 Mensagem: ${message:-"não encontrada"}"
            echo "   📁 Pasta solicitada: ${requested_folder:-"não encontrada"}"
            
            # Verificar se há debug info
            if echo "$response" | grep -q '"debug"'; then
                echo "   🔍 Resposta contém informações de debug"
                local available_folders=$(echo "$response" | sed -n '/"available_folders"/,/\]/p' | tr '\n' ' ')
                if [[ -n "$available_folders" ]]; then
                    echo "   📂 Pastas disponíveis encontradas no debug"
                fi
            fi
            
        else
            echo "⚠️ Resposta NÃO é JSON"
            echo "   📄 Tipo de conteúdo: $(echo "$response" | head -c 50)..."
        fi
        
        # Verificar resultado final
        if echo "$response" | grep -q '"success":[[:space:]]*true'; then
            echo
            echo "🎉 ✅ SUCESSO - Arquivo enviado com êxito!"
            ((success_count++))
        else
            echo
            echo "💥 ❌ FALHA - Arquivo não foi enviado"
            
            # Tentar extrair mensagem de erro mais específica
            local error_message=""
            if echo "$response" | grep -q '"message"'; then
                error_message=$(echo "$response" | grep -o '"message":[[:space:]]*"[^"]*"' | sed 's/.*"message":[[:space:]]*"\([^"]*\)".*/\1/')
            fi
            
            if [[ -n "$error_message" ]]; then
                echo "   📝 Erro reportado: $error_message"
                error_files+=("$(basename "$arquivo")")
                error_details+=("$error_message")
            else
                echo "   📄 Resposta completa (primeiros 500 chars):"
                echo "   ${response:0:500}"
                error_files+=("$(basename "$arquivo")")
                error_details+=("Resposta: ${response:0:200}")
            fi
            
            ((error_count++))
        fi
        
        # Pequena pausa para não sobrecarregar o servidor
        echo "⏸️ Pausa de 0.2s..."
        sleep 0.2
        echo
    done
    
    # Resumo final detalhado
    echo
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                           📊 RESUMO FINAL DETALHADO                   ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║ 📁 Pasta local: $pasta_local"
    echo "║ 🎯 Destino: $pasta_destino"
    if [[ -n "$subpasta" ]]; then
        echo "║ 📂 Subpasta: $subpasta"
    fi
    if [[ "$with_delete" == "true" ]]; then
        echo "║ 🗑️ Exclusão prévia: APLICADA"
    fi
    echo "║ ✅ Sucessos: $success_count"
    echo "║ ❌ Erros: $error_count" 
    echo "║ 📊 Total processado: $upload_count"
    echo "║ 📈 Taxa de sucesso: $(( success_count * 100 / upload_count ))%"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    
    # Mostrar detalhes dos erros se houver
    if [[ $error_count -gt 0 ]]; then
        echo
        echo "🚨 DETALHES DOS ERROS:"
        echo "════════════════════════"
        for i in "${!error_files[@]}"; do
            echo "❌ Arquivo $((i+1)): ${error_files[$i]}"
            echo "   💬 Erro: ${error_details[$i]}"
            echo
        done
        
        echo "🔧 SUGESTÕES PARA RESOLVER ERROS:"
        echo "• Verificar se a pasta de destino existe e está acessível"
        echo "• Confirmar se o token ainda é válido (tentar renovar)"
        echo "• Verificar conectividade de rede"
        echo "• Verificar se os nomes de arquivo contêm caracteres especiais"
        echo "• Tentar upload individual dos arquivos que falharam"
    fi
    
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
    echo "📊 Resultado final:"
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

is_sync_running() {
    if [[ -f "$SYNC_PID_FILE" ]]; then
        local pid=$(cat "$SYNC_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$SYNC_PID_FILE"
            return 1
        fi
    fi
    return 1
}

stop_sync() {
    if [[ -f "$SYNC_PID_FILE" ]]; then
        local pid=$(cat "$SYNC_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid" 2>/dev/null
            sleep 1
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null
            fi
        fi
        rm -f "$SYNC_PID_FILE"
        echo "✅ Sincronização parada"
    else
        echo "ℹ️ Nenhuma sincronização ativa"
    fi
}

get_sync_config() {
    if [[ -f "$SYNC_CONFIG_FILE" ]]; then
        cat "$SYNC_CONFIG_FILE"
    else
        echo "||"
    fi
}

sync_daemon() {
    local local_folder="$1"
    local destination="$2"
    local interval="$3"
    
    sync_log "🚀 Daemon iniciado para: $(basename "$local_folder")"
    
    while true; do
        if ! ps -p $PPID > /dev/null 2>&1; then
            exit 0
        fi
        
        check_and_sync_changes "$local_folder" "$destination"
        sleep "$interval"
    done
}

perform_sync_upload() {
    local file="$1"
    local destination="$2"
    local rel_path="$3"
    local with_delete="$4"  # Adicionar suporte ao with_delete
    
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]] || [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Corrigir caminho para curl
    local corrected_file="$file"
    if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
        if [[ "$file" =~ ^/c/ ]]; then
            corrected_file=$(echo "$file" | sed 's|^/c|C:|')
        fi
    fi
    
    # Usar EXATAMENTE o mesmo formato do upload manual
    local curl_cmd=(
        curl -s -X POST "$CONFIG_URL"
        -H "Authorization: Bearer $token"
        -F "arquivo[]=@$corrected_file"
        -F "pasta=$destination"
    )
    
    # Adicionar path apenas se não for raiz
    if [[ -n "$rel_path" && "$rel_path" != "." ]]; then
        curl_cmd+=(-F "path=$rel_path")
    fi
    
    # Adicionar with_delete se necessário
    if [[ "$with_delete" == "true" ]]; then
        curl_cmd+=(-F "with_delete=true")
    fi
    
    # Upload do arquivo
    local response=$("${curl_cmd[@]}" 2>&1)
    local curl_exit=$?
    
    # Verificar sucesso usando o mesmo método do upload manual
    if [[ $curl_exit -eq 0 ]] && echo "$response" | grep -q '"success":[[:space:]]*true'; then
        return 0
    else
        sync_log "❌ Erro no upload: $response"
        return 1
    fi
}


check_and_sync_changes() {
    local local_folder="$1"
    local destination="$2"
    local with_delete="$3"  # Adicionar parâmetro with_delete
    
    if [[ ! -d "$local_folder" ]]; then
        return 1
    fi
    
    local current_cache=""
    local old_cache=""
    
    # Carregar cache anterior
    if [[ -f "$SYNC_CACHE_FILE" ]]; then
        old_cache=$(cat "$SYNC_CACHE_FILE")
    fi
    
    # Gerar cache atual
    current_cache=$(find "$local_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort)
    
    # Comparar e encontrar arquivos modificados
    local files_to_sync=()
    
    while IFS='|' read -r file_path timestamp size; do
        [[ -z "$file_path" ]] && continue
        
        local old_entry=$(echo "$old_cache" | grep "^$file_path|")
        if [[ -z "$old_entry" ]]; then
            # Arquivo novo
            files_to_sync+=("$file_path")
            sync_log "🆕 Novo: $(basename "$file_path")"
        else
            local old_timestamp=$(echo "$old_entry" | cut -d'|' -f2)
            if [[ "$timestamp" != "$old_timestamp" ]]; then
                # Arquivo modificado
                files_to_sync+=("$file_path")
                sync_log "✏️ Modificado: $(basename "$file_path")"
            fi
        fi
    done <<< "$current_cache"
    
    # Se há mudanças, fazer upload dos arquivos modificados
    if [[ ${#files_to_sync[@]} -gt 0 ]]; then
        sync_log "🔄 ${#files_to_sync[@]} mudanças detectadas - sincronizando..."
        
        local sync_success=0
        local sync_failed=0
        local delete_applied=false
        
        for file in "${files_to_sync[@]}"; do
            # Calcular caminho relativo para preservar estrutura
            local rel_path=""
            if command -v realpath >/dev/null 2>&1; then
                rel_path=$(realpath --relative-to="$local_folder" "$file" 2>/dev/null || echo "${file#$local_folder/}")
            else
                # Fallback para sistemas sem realpath
                rel_path="${file#$local_folder/}"
                rel_path="${rel_path#/}"  # Remove barra inicial se existir
            fi
            
            sync_log "📤 Enviando: $rel_path"
            
            # Aplicar with_delete apenas no PRIMEIRO arquivo (igual ao upload de pasta)
            local current_with_delete="false"
            if [[ "$with_delete" == "true" && "$delete_applied" == "false" ]]; then
                current_with_delete="true"
                delete_applied=true
                sync_log "🗑️ Aplicando exclusão prévia neste primeiro envio..."
            fi
            
            # Tentar upload do arquivo individual
            if perform_sync_upload "$file" "$destination" "$rel_path" "$current_with_delete"; then
                sync_log "✅ Sincronizado: $(basename "$file")"
                ((sync_success++))
            else
                sync_log "❌ Falha: $(basename "$file")"
                ((sync_failed++))
            fi
            
            # Pequena pausa entre uploads
            sleep 0.2
        done
        
        if [[ $sync_success -gt 0 ]]; then
            sync_log "✅ Sincronização: $sync_success sucessos, $sync_failed falhas"
            # Atualizar cache apenas se houve sucessos
            echo "$current_cache" > "$SYNC_CACHE_FILE"
        else
            sync_log "❌ Sincronização falhou completamente"
        fi
    fi
}
setup_sync_for_folder() {
    local selected_folder="$1"
    
    clear_screen
    echo "🔄 Configurar Sincronização"
    echo "═════════════════════════"
    echo "📁 Pasta: $(basename "$selected_folder")"
    echo "🔗 Caminho: $selected_folder"
    echo
    
    # Parar sincronização atual se existir
    if is_sync_running; then
        echo "⚠️ Parando sincronização atual..."
        stop_sync
        sleep 2
    fi
    
    # Carregar pastas do usuário logado
    load_user_folders
    
    # Verificar se temos pastas disponíveis
    if [[ ${#user_folders[@]} -eq 0 ]]; then
        echo "❌ Nenhuma pasta disponível"
        echo "🔄 Tente fazer login novamente"
        pause
        return
    fi
    
    # Selecionar destino das pastas do usuário
    local destination=$(printf '%s\n' "${user_folders[@]}" | \
        fzf --prompt="Destino > " \
            --header="Selecione onde sincronizar (${#user_folders[@]} pastas disponíveis)" \
            --height=$((${#user_folders[@]} + 5)))
    
    if [[ -z "$destination" ]]; then
        echo "❌ Configuração cancelada"
        sleep 2
        return
    fi
    
    # Verificar opção de exclusão para sincronização
    local with_delete=false
    if confirm_delete_option "sincronização"; then
        with_delete=true
    fi
    
    # Selecionar intervalo
    local intervals=(
        "1|⚡ 1 segundo"
        "10|⏰ 10 segundos"
        "60|⏰ 1 minuto"
        "300|🐌 5 minutos"
        "600|🐌 10 minutos"
    )
    
    local interval_choice=$(printf '%s\n' "${intervals[@]}" | \
        sed 's/^[^|]*|//' | \
        fzf --prompt="Intervalo > " \
            --header="Frequência de verificação de mudanças" \
            --height=10)
    
    if [[ -z "$interval_choice" ]]; then
        echo "❌ Configuração cancelada"
        sleep 2
        return
    fi
    
    local interval=""
    for item in "${intervals[@]}"; do
        if [[ "$item" == *"|$interval_choice" ]]; then
            interval=$(echo "$item" | cut -d'|' -f1)
            break
        fi
    done
    
    # Salvar configuração incluindo with_delete
    echo "$selected_folder|$destination|$interval|$with_delete" > "$SYNC_CONFIG_FILE"
    
    # Criar cache inicial
    echo "🔄 Criando cache inicial..."
    find "$selected_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort > "$SYNC_CACHE_FILE"
    
    clear_screen
    echo "✅ Sincronização Configurada!"
    echo "═══════════════════════════"
    echo "📁 Pasta: $(basename "$selected_folder")"
    echo "🎯 Destino: $destination"
    echo "⏱️ Intervalo: $interval segundos"
    if [[ "$with_delete" == "true" ]]; then
        echo "🗑️ Exclusão prévia: ATIVA"
    else
        echo "🗑️ Exclusão prévia: INATIVA"
    fi
    echo
    
    if confirm "🚀 Iniciar sincronização agora?"; then
        start_sync
        
        echo
        echo "✅ Sincronização ativa!"
        echo "💡 Use 'Ver Status' para monitorar em tempo real"
        sleep 2
    fi
    
    pause
}

test_sync_single() {
    local config=$(get_sync_config)
    local local_folder=$(echo "$config" | cut -d'|' -f1)
    local destination=$(echo "$config" | cut -d'|' -f2)
    
    if [[ -z "$local_folder" || -z "$destination" ]]; then
        echo "❌ Sincronização não configurada"
        pause
        return
    fi
    
    clear_screen
    echo "🧪 Teste de Sincronização"
    echo "═══════════════════════"
    echo "📁 Pasta: $(basename "$local_folder")"
    echo "🎯 Destino: $destination"
    echo
    
    echo "🔍 Verificando mudanças..."
    
    # Simular verificação sem fazer upload
    local current_cache=""
    local old_cache=""
    
    if [[ -f "$SYNC_CACHE_FILE" ]]; then
        old_cache=$(cat "$SYNC_CACHE_FILE")
    fi
    
    current_cache=$(find "$local_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort)
    
    local files_to_sync=()
    
    while IFS='|' read -r file_path timestamp size; do
        [[ -z "$file_path" ]] && continue
        
        local old_entry=$(echo "$old_cache" | grep "^$file_path|")
        if [[ -z "$old_entry" ]]; then
            files_to_sync+=("$file_path")
            echo "🆕 Novo: $(basename "$file_path")"
        else
            local old_timestamp=$(echo "$old_entry" | cut -d'|' -f2)
            if [[ "$timestamp" != "$old_timestamp" ]]; then
                files_to_sync+=("$file_path")
                echo "✏️ Modificado: $(basename "$file_path")"
            fi
        fi
    done <<< "$current_cache"
    
    echo
    if [[ ${#files_to_sync[@]} -eq 0 ]]; then
        echo "✅ Nenhuma mudança detectada"
    else
        echo "📊 ${#files_to_sync[@]} arquivos precisam ser sincronizados"
        echo
        if confirm "Executar sincronização destes arquivos?"; then
            check_and_sync_changes "$local_folder" "$destination"
        fi
    fi
    
    pause
}

sync_menu() {
    while true; do
        clear_screen
        echo "🔄 Sincronização de Pasta"
        echo "════════════════════════"
        
        local is_running=false
        if is_sync_running; then
            is_running=true
            echo "🟢 Status: ATIVO"
        else
            echo "🔴 Status: INATIVO"
        fi
        
        local config=$(get_sync_config)
        local local_folder=$(echo "$config" | cut -d'|' -f1)
        local destination=$(echo "$config" | cut -d'|' -f2)
        local interval=$(echo "$config" | cut -d'|' -f3)
        
        echo "─────────────────────────"
        if [[ -n "$local_folder" && -n "$destination" ]]; then
            echo "📁 Pasta: $(basename "$local_folder")"
            echo "🎯 Destino: $destination"
            echo "⏱️ Intervalo: ${interval:-30}s"
        else
            echo "⚠️ Nenhuma sincronização configurada"
        fi
        echo
        
        local sync_options=()
        
        if [[ -n "$local_folder" && -n "$destination" ]]; then
            if $is_running; then
                sync_options+=("stop|⏹️ Parar Sincronização")
                sync_options+=("status|📊 Ver Status")
            else
                sync_options+=("start|▶️ Iniciar Sincronização")
            fi
            sync_options+=("reconfig|🔧 Reconfigurar")
            sync_options+=("manual|🔄 Sincronização Manual")
            sync_options+=("test|🧪 Testar Sincronização (apenas verificar)")
        else
            sync_options+=("config|⚙️ Configurar Sincronização")
        fi
        
        sync_options+=("back|🔙 Voltar ao Menu Principal")
        
        local choice=$(printf '%s\n' "${sync_options[@]}" | \
            sed 's/^[^|]*|//' | \
            fzf --prompt="Sincronização > " \
                --header="Sincronização automática de pastas" \
                --height=14)
        
        [[ -z "$choice" ]] && return
        
        for option in "${sync_options[@]}"; do
            if [[ "$option" == *"|$choice" ]]; then
                local action=$(echo "$option" | cut -d'|' -f1)
                
                case "$action" in
                    "config"|"reconfig")
                        configure_sync
                        ;;
                    "start")
                        start_sync
                        ;;
                    "stop")
                        stop_sync
                        pause
                        ;;
                    "status")
                        show_sync_status
                        ;;
                    "manual")
                        manual_sync
                        ;;
                    "test")
                        test_sync_single
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

export_functions_for_daemon() {
    local daemon_script="$1"
    cat > "$daemon_script" << 'EOF'
#!/bin/bash
# Script do daemon de sincronização

# Configurações herdadas
CONFIG_URL=""
TOKEN_FILE=""
SYNC_CACHE_FILE=""
SYNC_LOG_FILE=""

# Função para log do sync
sync_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$SYNC_LOG_FILE"
    
    # Manter apenas as últimas 100 linhas do log
    if [[ -f "$SYNC_LOG_FILE" ]]; then
        tail -n 100 "$SYNC_LOG_FILE" > "$SYNC_LOG_FILE.tmp"
        mv "$SYNC_LOG_FILE.tmp" "$SYNC_LOG_FILE"
    fi
}

# Upload individual para sincronização (CORRIGIDO)
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
        return 1
    fi
    
    # Corrigir caminho para curl
    local corrected_file="$file"
    if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
        if [[ "$file" =~ ^/c/ ]]; then
            corrected_file=$(echo "$file" | sed 's|^/c|C:|')
        fi
    fi
    
    # Usar EXATAMENTE o mesmo formato do upload manual
    local curl_cmd=(
        curl -s -X POST "$CONFIG_URL"
        -H "Authorization: Bearer $token"
        -F "arquivo[]=@$corrected_file"
        -F "pasta=$destination"
    )
    
    # Adicionar path apenas se não for raiz
    if [[ -n "$rel_path" && "$rel_path" != "." ]]; then
        curl_cmd+=(-F "path=$rel_path")
    fi
    
    # Adicionar with_delete se necessário
    if [[ "$with_delete" == "true" ]]; then
        curl_cmd+=(-F "with_delete=true")
    fi
    
    # Upload do arquivo
    local response=$("${curl_cmd[@]}" 2>&1)
    local curl_exit=$?
    
    # Verificar sucesso usando o mesmo método do upload manual
    if [[ $curl_exit -eq 0 ]] && echo "$response" | grep -q '"success":[[:space:]]*true'; then
        return 0
    else
        sync_log "❌ Erro detalhado: $response"
        return 1
    fi
}

# Verificar e sincronizar mudanças (CORRIGIDO)
check_and_sync_changes() {
    local local_folder="$1"
    local destination="$2"
    local with_delete="$3"
    
    if [[ ! -d "$local_folder" ]]; then
        sync_log "❌ Pasta local não encontrada: $local_folder"
        return 1
    fi
    
    local current_cache=""
    local old_cache=""
    
    # Carregar cache anterior
    if [[ -f "$SYNC_CACHE_FILE" ]]; then
        old_cache=$(cat "$SYNC_CACHE_FILE")
    fi
    
    # Gerar cache atual
    current_cache=$(find "$local_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort)
    
    # Comparar e encontrar arquivos modificados/novos
    local files_to_sync=()
    
    while IFS='|' read -r file_path timestamp size; do
        [[ -z "$file_path" ]] && continue
        
        local old_entry=$(echo "$old_cache" | grep "^$file_path|")
        if [[ -z "$old_entry" ]]; then
            # Arquivo novo
            files_to_sync+=("$file_path")
            sync_log "🆕 NOVO: $(basename "$file_path")"
        else
            local old_timestamp=$(echo "$old_entry" | cut -d'|' -f2)
            if [[ "$timestamp" != "$old_timestamp" ]]; then
                # Arquivo modificado
                files_to_sync+=("$file_path")
                sync_log "✏️ MODIFICADO: $(basename "$file_path")"
            fi
        fi
    done <<< "$current_cache"
    
    # Se há mudanças, fazer upload dos arquivos modificados
    if [[ ${#files_to_sync[@]} -gt 0 ]]; then
        sync_log "🔄 SINCRONIZANDO ${#files_to_sync[@]} arquivo(s)..."
        
        local sync_success=0
        local sync_failed=0
        local delete_applied=false
        
        for file in "${files_to_sync[@]}"; do
            # Calcular caminho relativo para preservar estrutura
            local rel_path=""
            if command -v realpath >/dev/null 2>&1; then
                rel_path=$(realpath --relative-to="$local_folder" "$file" 2>/dev/null || echo "${file#$local_folder/}")
            else
                rel_path="${file#$local_folder/}"
                rel_path="${rel_path#/}"
            fi
            
            sync_log "📤 Enviando: $rel_path"
            
            # Aplicar with_delete apenas no PRIMEIRO arquivo
            local current_with_delete="false"
            if [[ "$with_delete" == "true" && "$delete_applied" == "false" ]]; then
                current_with_delete="true"
                delete_applied=true
                sync_log "🗑️ Aplicando exclusão prévia neste primeiro envio..."
            fi
            
            # Upload do arquivo
            if perform_sync_upload "$file" "$destination" "$rel_path" "$current_with_delete"; then
                sync_log "✅ SUCESSO: $(basename "$file")"
                ((sync_success++))
            else
                sync_log "❌ FALHA: $(basename "$file")"
                ((sync_failed++))
            fi
            
            # Pausa pequena entre uploads
            sleep 0.2
        done
        
        if [[ $sync_success -gt 0 ]]; then
            sync_log "✅ CONCLUÍDO: $sync_success sucessos, $sync_failed falhas"
            # Atualizar cache apenas se houve sucessos
            echo "$current_cache" > "$SYNC_CACHE_FILE"
        else
            sync_log "❌ SINCRONIZAÇÃO FALHOU COMPLETAMENTE"
        fi
    fi
}

# Daemon principal (CORRIGIDO)
sync_daemon() {
    local local_folder="$1"
    local destination="$2" 
    local interval="$3"
    local with_delete="$4"
    
    sync_log "🚀 DAEMON INICIADO"
    sync_log "📁 Pasta: $local_folder"
    sync_log "🎯 Destino: $destination"
    sync_log "⏱️ Intervalo: ${interval}s"
    sync_log "🗑️ Exclusão prévia: $with_delete"
    
    while true; do
        # Verificar se processo pai ainda existe
        if ! ps -p $PPID > /dev/null 2>&1; then
            sync_log "⚠️ Processo pai morreu - encerrando daemon"
            exit 0
        fi
        
        # Verificar mudanças e sincronizar
        check_and_sync_changes "$local_folder" "$destination" "$with_delete"
        
        # Aguardar intervalo
        sleep "$interval"
    done
}

# Iniciar daemon com parâmetros passados
if [[ "$1" == "start_daemon" ]]; then
    CONFIG_URL="$2"
    TOKEN_FILE="$3"
    SYNC_CACHE_FILE="$4"
    SYNC_LOG_FILE="$5"
    LOCAL_FOLDER="$6"
    DESTINATION="$7"
    INTERVAL="$8"
    WITH_DELETE="$9"
    
    sync_daemon "$LOCAL_FOLDER" "$DESTINATION" "$INTERVAL" "$WITH_DELETE"
fi
EOF
    chmod +x "$daemon_script"
}

configure_sync() {
    clear_screen
    echo "⚙️ Configurar Sincronização"
    echo "═══════════════════════════"
    echo
    echo "Use o navegador de arquivos para configurar sincronização"
    echo "Menu Principal → Navegador de Arquivos → Selecionar pasta → Sincronizar"
    pause
}

start_sync() {
    local config=$(get_sync_config)
    local local_folder=$(echo "$config" | cut -d'|' -f1)
    local destination=$(echo "$config" | cut -d'|' -f2)
    local interval=$(echo "$config" | cut -d'|' -f3)
    local with_delete=$(echo "$config" | cut -d'|' -f4)
    
    if [[ -z "$local_folder" || -z "$destination" ]]; then
        echo "❌ Sincronização não configurada"
        pause
        return
    fi
    
    if is_sync_running; then
        echo "⚠️ Sincronização já está ativa"
        pause
        return
    fi
    
    # Criar script temporário do daemon
    local daemon_script="/tmp/upcode_sync_daemon_$$.sh"
    export_functions_for_daemon "$daemon_script"
    
    # Iniciar daemon em background com parâmetro with_delete
    nohup "$daemon_script" "start_daemon" \
        "$CONFIG_URL" \
        "$TOKEN_FILE" \
        "$SYNC_CACHE_FILE" \
        "$SYNC_LOG_FILE" \
        "$local_folder" \
        "$destination" \
        "$interval" \
        "$with_delete" > /dev/null 2>&1 &
    
    local daemon_pid=$!
    echo "$daemon_pid" > "$SYNC_PID_FILE"
    
    # Limpar log anterior
    > "$SYNC_LOG_FILE"
    
    echo "✅ Sincronização iniciada!"
    echo "📁 Pasta: $(basename "$local_folder")"  
    echo "🎯 Destino: $destination"
    echo "⏱️ Intervalo: ${interval}s"
    if [[ "$with_delete" == "true" ]]; then
        echo "🗑️ Exclusão prévia: ATIVA"
    else
        echo "🗑️ Exclusão prévia: INATIVA"
    fi
    echo "🔍 PID: $daemon_pid"
    
    pause
}


show_sync_status() {
    clear_screen
    echo "📊 Status da Sincronização - TEMPO REAL"
    echo "═════════════════════════════════════"
    
    if ! is_sync_running; then
        echo "🔴 Sincronização não está ativa"
        pause
        return
    fi
    
    local config=$(get_sync_config)
    local local_folder=$(echo "$config" | cut -d'|' -f1)
    local destination=$(echo "$config" | cut -d'|' -f2)
    local interval=$(echo "$config" | cut -d'|' -f3)
    local pid=$(cat "$SYNC_PID_FILE" 2>/dev/null)
    
    echo "🟢 Status: ATIVO"
    echo "📁 Pasta: $(basename "$local_folder")"
    echo "🎯 Destino: $destination"
    echo "⏱️ Intervalo: $interval segundos"
    echo "🔍 PID: $pid"
    echo
    echo "📋 MONITOR EM TEMPO REAL:"
    echo "═══════════════════════════════════════"
    echo "Pressione Ctrl+C para sair do monitor"
    echo
    
    # Monitor em tempo real
    local last_line_count=0
    
    while true; do
        # Verificar se ainda está rodando
        if ! is_sync_running; then
            echo
            echo "❌ Sincronização parou de funcionar!"
            break
        fi
        
        # Contar linhas atuais do log
        local current_line_count=0
        if [[ -f "$SYNC_LOG_FILE" ]]; then
            current_line_count=$(wc -l < "$SYNC_LOG_FILE" 2>/dev/null || echo 0)
        fi
        
        # Se há novas linhas, mostrar apenas as novas
        if [[ $current_line_count -gt $last_line_count ]]; then
            local new_lines=$((current_line_count - last_line_count))
            echo "📄 Novas atividades detectadas ($new_lines):"
            echo "─────────────────────────────────"
            tail -n "$new_lines" "$SYNC_LOG_FILE" 2>/dev/null | while IFS= read -r line; do
                # Colorir diferentes tipos de mensagem
                if [[ "$line" == *"🆕 NOVO:"* ]]; then
                    echo "🟢 $line"
                elif [[ "$line" == *"✏️ MODIFICADO:"* ]]; then
                    echo "🟡 $line"
                elif [[ "$line" == *"✅ SUCESSO:"* ]]; then
                    echo "🟢 $line"
                elif [[ "$line" == *"❌ FALHA:"* ]]; then
                    echo "🔴 $line"
                elif [[ "$line" == *"📤 Enviando:"* ]]; then
                    echo "🔵 $line"
                else
                    echo "⚪ $line"
                fi
            done
            echo
            last_line_count=$current_line_count
        fi
        
        # Aguardar 1 segundo antes de verificar novamente
        sleep 1
        
        # Verificar se usuário quer sair (timeout de 0.1s)
        if read -t 0.1 -n 1 key 2>/dev/null; then
            if [[ "$key" == $'\x03' ]]; then # Ctrl+C
                break
            fi
        fi
    done
    
    echo
    echo "📊 Monitor finalizado"
    pause
}

manual_sync() {
    local config=$(get_sync_config)
    local local_folder=$(echo "$config" | cut -d'|' -f1)
    local destination=$(echo "$config" | cut -d'|' -f2)
    local with_delete=$(echo "$config" | cut -d'|' -f4)
    
    if [[ -z "$local_folder" || -z "$destination" ]]; then
        echo "❌ Sincronização não configurada"
        pause
        return
    fi
    
    clear_screen
    echo "🔄 Sincronização Manual"
    echo "═════════════════════"
    echo "📁 Pasta: $(basename "$local_folder")"
    echo "🎯 Destino: $destination"
    if [[ "$with_delete" == "true" ]]; then
        echo "🗑️ Exclusão prévia: ATIVA"
    else
        echo "🗑️ Exclusão prévia: INATIVA"
    fi
    echo
    
    echo "Escolha o tipo de sincronização:"
    echo "1) 🔄 Incremental (apenas arquivos modificados)"
    echo "2) 📤 Completa (todos os arquivos)"
    echo
    
    read -p "Opção (1-2): " sync_type
    
    case "$sync_type" in
        1)
            echo "🔄 Executando sincronização incremental..."
            check_and_sync_changes "$local_folder" "$destination" "$with_delete"
            echo "✅ Sincronização incremental concluída!"
            ;;
        2)
            echo "📤 Executando upload completo..."
            if upload_pasta_completa "$local_folder" "$destination" "" "$with_delete"; then
                echo "✅ Upload completo concluído!"
                # Atualizar cache
                find "$local_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort > "$SYNC_CACHE_FILE"
            fi
            ;;
        *)
            echo "❌ Opção inválida"
            ;;
    esac
    
    pause
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
            echo "📧 Email: $USER_EMAIL | 🎭 Tipo: $USER_TYPE"
        else
            echo "👤 Status: Não logado"
        fi
        echo
        
        # Verificar se há histórico
        local history_count=0
        if [[ -f "$HISTORY_FILE" ]]; then
            history_count=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
        fi
        
        # Verificar status da sincronização
        local sync_status="🔴 Inativa"
        if is_sync_running; then
            sync_status="🟢 Ativa"
        fi
        
        # Mostrar informações de status
        echo "📊 STATUS DO SISTEMA:"
        echo "   📦 Versão: $CURRENT_VERSION"
        echo "   🔄 Sincronização: $sync_status"
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
            "sync|🔄 Sincronização de Pasta ($sync_status)"
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
                    "sync") sync_menu ;;
                    "quick") quick_upload ;;
                    "history") show_upload_history ;;
                    "token") renew_token ;;
                    "clean") clean_data ;;
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
            "token|🔑 Limpar Token (força novo login)"
            "history|📝 Limpar Histórico de uploads"
            "sync|🔄 Limpar Configuração de Sincronização"
            "folders|📁 Limpar Cache de Pastas"
            "userinfo|👤 Limpar Dados do Usuário"
            "all|🗑️ Limpar TUDO (reset completo)"
            "back|🔙 Voltar"
        )
        
        local choice=$(printf '%s\n' "${clean_options[@]}" | \
            sed 's/^[^|]*|//' | \
            fzf --prompt="Limpar > " \
                --header="⚠️ Algumas ações forçarão novo login" \
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
                            sleep 1
                            
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
                            sleep 1
                        fi
                        ;;
                    "sync")
                        if confirm "Limpar configuração de sincronização?"; then
                            # Parar sincronização se estiver rodando
                            if is_sync_running; then
                                echo "⏹️ Parando sincronização..."
                                stop_sync
                            fi
                            rm -f "$SYNC_CONFIG_FILE" "$SYNC_CACHE_FILE" "$SYNC_LOG_FILE"
                            echo "✅ Sincronização limpa!"
                            sleep 1
                        fi
                        ;;
                    "folders")
                        if confirm "Limpar cache de pastas?"; then
                            rm -f "$USER_FOLDERS_FILE"
                            user_folders=()
                            echo "✅ Cache de pastas limpo!"
                            sleep 1
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
                            sleep 1
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
                            sleep 1
                            
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
