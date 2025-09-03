#===========================================
# MENU PRINCIPAL
#===========================================

main_menu() {
    while true; do
        clear_screen
        
        # Carregar dados do usuário para exibição
        load_user_info
        
        #echo "📡 Sistema ativo e conectado"
        #if [[ -n "$USER_DISPLAY_NAME" ]]; then
            #echo "👤 Logado como: $USER_DISPLAY_NAME ($USER_NICENAME)"
            #echo "📧 Email: $USER_EMAIL |  Tipo: $USER_TYPE"
        #else
            #echo "👤 Status: Não logado"
        #fi
        #echo
        
        # Verificar se há histórico
        local history_count=0
        if [[ -f "$HISTORY_FILE" ]]; then
            history_count=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
        fi
        

        # Mostrar informações de status
        #echo "📊 STATUS DO SISTEMA:"
        #echo "   📦 Versão: $CURRENT_VERSION"
        #echo "   📝 Histórico: $history_count itens"
        #if [[ ${#user_folders[@]} -gt 0 ]]; then
           # echo "   📁 Pastas disponíveis: ${#user_folders[@]}"
        #fi
        #echo
        
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
