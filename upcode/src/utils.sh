
#===========================================
# Funções utilitarias
#===========================================
show_banner() {
    clear
    # Usa ANSI escape codes para colorir o texto (exemplo: azul claro)
    echo -e "\e[96m
    ██╗   ██╗██████╗  ██████╗ ██████╗ ██████╗ ███████╗
    ██║   ██║██╔══██╗██╔════╝██╔═══██╗██╔══██╗██╔════╝
    ██║   ██║██████╔╝██║     ██║   ██║██║  ██║█████╗  
    ██║   ██║██╔═══╝ ██║     ██║   ██║██║  ██║██╔══╝  
    ╚██████╔╝██║     ╚██████╗╚██████╔╝██████╔╝███████╗
     ╚═════╝ ╚═╝      ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
    \e[0m"
    echo -e "\e[93m    🚀 Sistema de upload arquivos via terminal. v$CURRENT_VERSION\e[0m"
    echo -e "\e[90m    ═══════════════════════════════════════════════\e[0m"
    echo

    sleep 1
}


# Limpar tela 
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


limpar_tudo() {
    echo "🧹 Limpando todos os dados do upcode..."
    
    # Remover pasta inteira
    if [[ -d "$UPCODE_DIR" ]]; then
        rm -rf "$UPCODE_DIR"
        echo "✅ Pasta $UPCODE_DIR removida"
    fi
    
    # Remover arquivos antigos soltos 
    rm -f "$HOME/.upcode_token" 2>/dev/null
    rm -f "$HOME/.upcode_history" 2>/dev/null
    rm -f "$HOME/.upcode_user_folders" 2>/dev/null
    rm -f "$HOME/.upcode_user_info" 2>/dev/null
    rm -f "$HOME/.upcode_sync.log" 2>/dev/null
    rm -f "$HOME/.upcode_sync.cache" 2>/dev/null
    
    # Limpar variáveis
    USER_DISPLAY_NAME=""
    USER_NICENAME=""
    USER_EMAIL=""
    USER_TYPE=""
    USER_CAN_DELETE=""
    USER_CANNOT_DELETE_FOLDERS_STR=""
    USER_CANNOT_DELETE_FOLDERS=()
    user_folders=()
    
    echo "✅ Limpeza completa realizada - faça login novamente"
    pause
}
