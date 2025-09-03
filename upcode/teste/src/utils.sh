
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
clean_all_data() {
    clear_screen
    echo "🧹 LIMPEZA COMPLETA DE DADOS"
    echo "═══════════════════════════"
    echo
    
    # Mostrar o que será removido
    if [[ -d "$UPCODE_TEMP_DIR" ]]; then
        echo "📁 Pasta de dados: $UPCODE_TEMP_DIR"
        echo "📄 Arquivos que serão removidos:"
        
        if [[ -f "$TOKEN_FILE" ]]; then
            echo "   🔑 Token de autenticação"
        fi
        if [[ -f "$USER_FOLDERS_FILE" ]]; then
            echo "   📂 Cache de pastas do usuário"
        fi
        if [[ -f "${USER_FOLDERS_FILE}.permissions" ]]; then
            echo "   🔒 Permissões das pastas"
        fi
        if [[ -f "$USER_INFO_FILE" ]]; then
            echo "   👤 Informações do usuário"
        fi
        if [[ -f "$HISTORY_FILE" ]]; then
            echo "   📋 Histórico de uploads"
        fi
        if [[ -f "$SYNC_LOG_FILE" ]]; then
            echo "   🔄 Log de sincronização"
        fi
        if [[ -f "$SYNC_CACHE_FILE" ]]; then
            echo "   💾 Cache de sincronização"
        fi
        
        # Mostrar outros arquivos que possam existir
        local other_files=$(find "$UPCODE_TEMP_DIR" -type f ! -name "token" ! -name "user_folders" ! -name "user_folders.permissions" ! -name "user_info" ! -name "upload_history" ! -name "sync.log" ! -name "sync.cache" 2>/dev/null)
        if [[ -n "$other_files" ]]; then
            echo "   📄 Outros arquivos encontrados:"
            echo "$other_files" | while read -r file; do
                echo "      $(basename "$file")"
            done
        fi
        
        echo
        echo "💾 Tamanho total: $(du -sh "$UPCODE_TEMP_DIR" 2>/dev/null | cut -f1 || echo "N/A")"
    else
        echo "ℹ️ Nenhum dado encontrado para limpar"
        pause
        return
    fi
    
    echo
    echo "⚠️ ATENÇÃO:"
    echo "   • Esta ação removerá TODOS os dados salvos do upcode"
    echo "   • Você precisará fazer login novamente"
    echo "   • O histórico de uploads será perdido"
    echo "   • Os dados de sincronização serão perdidos"
    echo "   • Ação IRREVERSÍVEL"
    
    if confirm "🗑️ Confirma a limpeza completa?"; then
        echo
        echo "🧹 Removendo dados..."
        
        # Limpar variáveis primeiro
        USER_DISPLAY_NAME=""
        USER_NICENAME=""
        USER_EMAIL=""
        USER_TYPE=""
        USER_CAN_DELETE=""
        user_folders=()
        
        # Remover toda a pasta
        if rm -rf "$UPCODE_TEMP_DIR" 2>/dev/null; then
            echo "✅ Todos os dados foram removidos com sucesso!"
            echo "📁 Pasta removida: $UPCODE_TEMP_DIR"
        else
            echo "❌ Erro ao remover alguns arquivos"
            echo "🔧 Tentando limpeza individual..."
            
            # Tentar remover arquivos individuais
            rm -f "$TOKEN_FILE" "$USER_FOLDERS_FILE" "$USER_INFO_FILE" "$HISTORY_FILE" "${USER_FOLDERS_FILE}.permissions" "$SYNC_LOG_FILE" "$SYNC_CACHE_FILE" 2>/dev/null
            echo "✅ Limpeza individual concluída"
        fi
        
        echo
        echo "🔄 Reinicie o upcode para fazer novo login"
    else
        echo "ℹ️ Limpeza cancelada"
    fi
    
    pause
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
