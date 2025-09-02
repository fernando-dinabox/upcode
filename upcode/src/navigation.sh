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
                    
                    items+=("")    
                    items+=("UPLOAD_FOLDER_AS_STRUCTURE|| 1. ENVIAR PASTA COMPLETA: $(basename "$current_dir")")
                    items+=("UPLOAD_CURRENT|| 2. ENVIAR CONTEÚDO DA PASTA: $(basename "$current_dir")")
                    items+=("SYNC_FOLDER|| 3. 🔄 SINCRONIZAR ESTA PASTA: $(basename "$current_dir")")
                    items+=("HISTORY|| 4. VER HISTÓRICO")
                    items+=("")
        fi
        
        
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
