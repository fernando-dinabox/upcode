#!/bin/bash
# filepath: upcode-main.sh

#===========================================
# CONFIGURAÇÕES
#===========================================

CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
AUTH_URL="https://db33.dev.dinabox.net/api/dinabox/system/users/auth"
TOKEN_FILE="$HOME/.upcode_token"
HISTORY_FILE="$HOME/.upcode_history"
SYNC_CONFIG_FILE="$HOME/.upcode_sync_config"
SYNC_CACHE_FILE="$HOME/.upcode_sync_cache"
SYNC_PID_FILE="$HOME/.upcode_sync_pid"
SYNC_LOG_FILE="$HOME/.upcode_sync_debug.log"

# Array para arquivos selecionados
declare -a selected_files=()

# Configurações de interface
FZF_DEFAULT_OPTS="--height=40% --border --margin=1 --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9"

#===========================================
# UTILITÁRIOS
#===========================================

# Verificar dependências
check_dependencies() {
    if ! command -v fzf &> /dev/null; then
        echo "❌ Erro: fzf não encontrado"
        echo "📦 Execute: sudo apt install fzf"
        exit 1
    fi
}

# Função para pausar
pause() {
    echo
    read -p "Pressione Enter para continuar..." </dev/tty
}

# Função para confirmação
confirm() {
    local message="$1"
    read -p "$message (s/N): " -n 1 response </dev/tty
    echo
    [[ "$response" =~ ^[sS]$ ]]
}

# Limpar tela
clear_screen() {
    clear
    echo "🚀 UPCODE - Sistema de Upload"
    echo "═════════════════════════════"
    echo
}

#===========================================
# AUTENTICAÇÃO
#===========================================

# Verificar se token existe e é válido
check_token() {
    if [[ -f "$TOKEN_FILE" ]]; then
        local token=$(cat "$TOKEN_FILE" 2>/dev/null)
        if [[ -n "$token" && "$token" != "null" ]]; then
            return 0
        fi
    fi
    return 1
}

# Fazer login e obter token
do_login() {
    clear_screen
    echo "🔐 Login necessário"
    echo "─────────────────"
    
    read -p "👤 Usuário [db17]: " username </dev/tty
    username=${username:-db17}  # Default para db17
    read -s -p "🔑 Senha: " password </dev/tty
    echo
    
    # Validação
    if [[ -z "$username" || -z "$password" ]]; then
        echo "❌ Usuário e senha são obrigatórios!"
        pause
        exit 1
    fi
    
    echo "🔄 Autenticando..."
    
    # Fazer requisição de login
    local response=$(curl -s -X POST \
        -d "username=$username" \
        -d "password=$password" \
        "$AUTH_URL")
    
    # Extrair token da resposta JSON
    local token=$(echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    if [[ -n "$token" && "$token" != "null" ]]; then
        # Salvar token
        echo "$token" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        echo "✅ Login realizado com sucesso!"
        sleep 1
        return 0
    else
        echo "❌ Falha na autenticação!"
        echo "Resposta: $response"
        pause
        exit 1
    fi
}

# Renovar token
renew_token() {
    rm -f "$TOKEN_FILE"
    do_login
}

#===========================================
# HISTÓRICO E FAVORITOS
#===========================================

# Adicionar arquivo ao histórico
add_to_history() {
    local item="$1"
    local item_type="$2"  # "file" ou "folder"
    local destination="$3"
    
    # Criar arquivo de histórico se não existir
    touch "$HISTORY_FILE"
    
    # Formato: tipo|caminho|destino|timestamp
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
# NAVEGAÇÃO DE ARQUIVOS - VERSÃO MELHORADA
#===========================================

# Navegador de arquivos com suporte para pastas
file_browser() {
    # Determinar diretório inicial
    local current_dir="${1:-$HOME}"
    
    # Se for Windows/WSL, começar em /mnt/c/Users se possível
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
        
        # Opção para voltar (se não estiver na raiz)
        if [[ "$current_dir" != "/" && "$current_dir" != "/mnt/c" ]]; then
            items+=(".. [🔙 Voltar]")
        fi
        
        # Opção para enviar a pasta atual
        items+=("")
        items+=("UPLOAD_CURRENT||📂 ENVIAR ESTA PASTA: $(basename "$current_dir")")
        items+=("SYNC_CURRENT||🔄 SINCRONIZAR ESTA PASTA: $(basename "$current_dir")")
        items+=("")
        
        # Adicionar seção de conteúdo
        items+=("--- [📤 CONTEÚDO ATUAL] ---")
        
        # Listar diretórios e arquivos de forma mais eficiente
        local dir_count=0
        local file_count=0
        
        # Usar ls ao invés de find para ser mais rápido
        if [[ -r "$current_dir" ]]; then
            # Listar diretórios primeiro
            while IFS= read -r item; do
                [[ -z "$item" ]] && continue
                local full_path="$current_dir/$item"
                if [[ -d "$full_path" ]]; then
                    items+=("DIR|$full_path|📂 $item/")
                    ((dir_count++))
                fi
            done < <(ls -1 "$current_dir" 2>/dev/null | head -50)  # Limitar a 50 itens para velocidade
            
            # Listar arquivos
            while IFS= read -r item; do
                [[ -z "$item" ]] && continue
                local full_path="$current_dir/$item"
                if [[ -f "$full_path" ]]; then
                    local size=$(du -sh "$full_path" 2>/dev/null | cut -f1 || echo "?")
                    
                    # Verificar se está no histórico
                    local history_mark=""
                    if [[ -f "$HISTORY_FILE" ]] && grep -q "^$full_path$" "$HISTORY_FILE" 2>/dev/null; then
                        history_mark="⭐ "
                    fi
                    
                    items+=("FILE|$full_path|📄 $history_mark$item ($size)")
                    ((file_count++))
                fi
            done < <(ls -1 "$current_dir" 2>/dev/null | head -30)  # Limitar a 30 arquivos
        else
            items+=("❌ Sem permissão para ler este diretório")
        fi
        
        # Adicionar opções de controle
        items+=("")
        items+=("--- [🛠️ OPÇÕES] ---")
        items+=("HISTORY||📝 Ver histórico ($([[ -f "$HISTORY_FILE" ]] && wc -l < "$HISTORY_FILE" || echo 0) itens)")
        items+=("BACK||🔙 Voltar ao menu principal")
        
        # Mostrar contador e informações da pasta atual
        echo "📊 Encontrados: $dir_count pastas, $file_count arquivos"
        echo "📂 Pasta atual: $(basename "$current_dir")"
        echo "🔗 Caminho: $current_dir"
        
        # Verificar se esta pasta está sendo sincronizada
        local config=$(get_sync_config)
        local sync_folder=$(echo "$config" | cut -d'|' -f1)
        if [[ "$sync_folder" == "$current_dir" ]]; then
            if is_sync_running; then
                echo "🟢 Status: Esta pasta está sendo sincronizada automaticamente"
            else
                echo "🔴 Status: Sincronização configurada mas inativa"
            fi
        fi
        echo
        
        # Mostrar seletor
        local choice=$(printf '%s\n' "${items[@]}" | \
            sed 's/^[^|]*|[^|]*|//' | \
            fzf --prompt="📁 $(basename "$current_dir") > " \
                --header="Enter = Navegar/Selecionar | Esc = Voltar" \
                --preview-window=hidden)
        
        # Sair se cancelado
        [[ -z "$choice" ]] && return
        
        # Encontrar a linha completa selecionada
        local selected_line=""
        for item in "${items[@]}"; do
            if [[ "$item" == *"|$choice" ]]; then
                selected_line="$item"
                break
            fi
        done
        
        # Processar escolha
        local action=$(echo "$selected_line" | cut -d'|' -f1)
        local path=$(echo "$selected_line" | cut -d'|' -f2)
        
        case "$action" in
            "..")
                current_dir=$(dirname "$current_dir")
                ;;
            "DIR")
                current_dir="$path"
                ;;
            "FILE")
                show_file_options "$path"
                ;;
            "UPLOAD_CURRENT")
                upload_folder "$current_dir"
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
            "")
                # Linhas vazias ou separadores - ignorar
                continue
                ;;
            *)
                # Se não conseguiu processar, talvez seja uma seleção direta
                if [[ "$choice" == *"[🔙 Voltar]" ]]; then
                    current_dir=$(dirname "$current_dir")
                elif [[ "$choice" == *"📂"* && "$choice" == *"/" ]]; then
                    # É um diretório
                    local folder_name=$(echo "$choice" | sed 's/📂 //' | sed 's/\/$//')
                    current_dir="$current_dir/$folder_name"
                fi
                ;;
        esac
    done
}

# Mostrar opções para arquivo selecionado
show_file_options() {
    local file="$1"
    
    clear_screen
    echo "📄 Arquivo: $(basename "$file")"
    echo "📁 Local: $(dirname "$file")"
    echo "─────────────────────────────────"
    
    local options=(
        "upload|📤 Upload deste arquivo"
        "info|ℹ️ Informações do arquivo"
        "back|🔙 Voltar"
    )
    
    local choice=$(printf '%s\n' "${options[@]}" | \
        sed 's/^[^|]*|//' | \
        fzf --prompt="Ações > " \
            --header="Escolha uma ação para o arquivo" \
            --height=10)
    
    # Encontrar a ação correspondente
    for option in "${options[@]}"; do
        if [[ "$option" == *"|$choice" ]]; then
            local action=$(echo "$option" | cut -d'|' -f1)
            case "$action" in
                "upload") upload_single_file "$file" ;;
                "info") show_file_info "$file" ;;
                "back") return ;;
            esac
            break
        fi
    done
}

# Mostrar informações do arquivo
show_file_info() {
    local file="$1"
    
    clear_screen
    echo "ℹ️ Informações do Arquivo"
    echo "─────────────────────────"
    echo "📄 Nome: $(basename "$file")"
    echo "📁 Pasta: $(dirname "$file")"
    echo "💾 Tamanho: $(du -sh "$file" 2>/dev/null | cut -f1 || echo "N/A")"
    echo "📅 Modificado: $(stat -c '%y' "$file" 2>/dev/null | cut -d. -f1 || echo "N/A")"
    echo "🔗 Caminho completo: $file"
    echo "📝 Tipo: $(file -b "$file" 2>/dev/null || echo "Desconhecido")"
    
    # Verificar se está no histórico
    if [[ -f "$HISTORY_FILE" ]] && grep -q "^$file$" "$HISTORY_FILE" 2>/dev/null; then
        echo "⭐ Status: Já foi enviado anteriormente"
    else
        echo "📝 Status: Nunca foi enviado"
    fi
    
    echo
    pause
}

# Mostrar histórico de uploads - MELHORADO
show_upload_history() {
    if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
        clear_screen
        echo "📝 Histórico de Uploads"
        echo "─────────────────────"
        echo "Nenhum item foi enviado ainda"
        pause
        return
    fi
    
    local history_items=()
    while IFS='|' read -r item_type item_path destination timestamp; do
        if [[ "$item_type" == "file" ]] && [[ -f "$item_path" ]]; then
            local size=$(du -sh "$item_path" 2>/dev/null | cut -f1 || echo "?")
            local basename_item=$(basename "$item_path")
            history_items+=("FILE|$item_path|$destination|📄 $basename_item ($size) → $destination")
        elif [[ "$item_type" == "folder" ]] && [[ -d "$item_path" ]]; then
            local size=$(du -sh "$item_path" 2>/dev/null | cut -f1 || echo "?")
            local basename_item=$(basename "$item_path")
            history_items+=("FOLDER|$item_path|$destination|📁 $basename_item ($size) → $destination")
        fi
    done < <(tac "$HISTORY_FILE")  # Inverter ordem (mais recentes primeiro)
    
    if [[ ${#history_items[@]} -eq 0 ]]; then
        clear_screen
        echo "📝 Histórico de Uploads"
        echo "─────────────────────"
        echo "Nenhum item disponível no histórico"
        pause
        return
    fi
    
    local choice=$(printf '%s\n' "${history_items[@]}" | \
        sed 's/^[^|]*|[^|]*|[^|]*|//' | \
        fzf --prompt="Histórico > " \
            --header="Selecione um item para reenviar")
    
    if [[ -n "$choice" ]]; then
        # Encontrar o item correspondente
        for item in "${history_items[@]}"; do
            if [[ "$item" == *"|$choice" ]]; then
                local item_type=$(echo "$item" | cut -d'|' -f1)
                local selected_path=$(echo "$item" | cut -d'|' -f2)
                local last_destination=$(echo "$item" | cut -d'|' -f3)
                
                if [[ "$item_type" == "FILE" ]]; then
                    clear_screen
                    echo "🔄 Reenvio Rápido - Arquivo"
                    echo "───────────────────────────"
                    echo "📄 Arquivo: $(basename "$selected_path")"
                    echo "📁 Último destino: $last_destination"
                    echo
                    
                    if confirm "Reenviar para a mesma pasta?"; then
                        if perform_upload "$selected_path" "$last_destination"; then
                            add_to_history "$selected_path" "file" "$last_destination"
                        fi
                    fi
                elif [[ "$item_type" == "FOLDER" ]]; then
                    clear_screen
                    echo "🔄 Reenvio Rápido - Pasta"
                    echo "─────────────────────────"
                    echo "📁 Pasta: $(basename "$selected_path")"
                    echo "📁 Último destino: $last_destination"
                    echo
                    
                    if confirm "Reenviar pasta para a mesma pasta?"; then
                        if perform_folder_upload "$selected_path" "$last_destination"; then
                            add_to_history "$selected_path" "folder" "$last_destination"
                        fi
                    fi
                fi
                break
            fi
        done
    fi
}

#===========================================
# UPLOAD
#===========================================

# Upload de pasta inteira
upload_folder() {
    local folder="$1"
    
    if [[ ! -d "$folder" ]]; then
        echo "❌ Pasta não encontrada: $folder"
        pause
        return 1
    fi
    
    clear_screen
    echo "📁 Upload de Pasta Completa"
    echo "═══════════════════════════"
    echo "🎯 PASTA SELECIONADA:"
    echo "   📂 Nome: $(basename "$folder")"
    echo "   � Caminho: $folder"
    echo
    
    # Contar arquivos na pasta
    echo "🔄 Analisando conteúdo da pasta..."
    local file_count=$(find "$folder" -type f 2>/dev/null | wc -l)
    local dir_count=$(find "$folder" -type d 2>/dev/null | wc -l)
    local total_size=$(du -sh "$folder" 2>/dev/null | cut -f1 || echo "?")
    
    echo "📊 Estatísticas:"
    echo "   📄 Arquivos: $file_count"
    echo "   📁 Subpastas: $((dir_count - 1))"
    echo "   💾 Tamanho total: $total_size"
    echo
    
    # Mostrar alguns arquivos como exemplo
    echo "📋 Alguns arquivos que serão enviados:"
    find "$folder" -type f | head -5 | while read -r file; do
        echo "   📄 $(basename "$file")"
    done
    if [[ $file_count -gt 5 ]]; then
        echo "   ... e mais $((file_count - 5)) arquivos"
    fi
    echo
    
    # Selecionar pasta de destino
    local folders=(
        "Cutprefers (endpoint)"
        "Resources (projetos avulso)"
        "Configurador de máquinas (out)"
        "teste fernando"
    )
    
    local destination=$(printf '%s\n' "${folders[@]}" | \
        fzf --prompt="🎯 Destino da pasta > " \
            --header="⚠️ TODOS os $file_count arquivos da pasta serão enviados!" \
            --height=10)
    
    [[ -z "$destination" ]] && return
    
    echo
    echo "📋 CONFIRMAÇÃO DE UPLOAD:"
    echo "═══════════════════════════"
    echo "🎯 Pasta origem: $(basename "$folder")"
    echo "📁 Pasta destino: $destination"
    echo "📊 Total de arquivos: $file_count"
    echo "💾 Tamanho total: $total_size"
    echo "⚠️  ATENÇÃO: Todos os arquivos da pasta serão enviados!"
    echo
    
    if confirm "🚀 CONFIRMAR UPLOAD DA PASTA COMPLETA?"; then
        if perform_folder_upload "$folder" "$destination"; then
            add_to_history "$folder" "folder" "$destination"
        fi
    else
        echo "❌ Upload cancelado"
        sleep 1
    fi
}

# Upload de arquivo único
upload_single_file() {
    local file="$1"
    
    # Verificar se arquivo existe
    if [[ ! -f "$file" ]]; then
        echo "❌ Arquivo não encontrado: $file"
        pause
        return 1
    fi
    
    clear_screen
    echo "📤 Upload de Arquivo"
    echo "──────────────────"
    echo "📄 Arquivo: $(basename "$file")"
    echo "💾 Tamanho: $(du -sh "$file" 2>/dev/null | cut -f1 || echo "N/A")"
    echo
    
    # Selecionar pasta de destino
    local folders=(
        "Cutprefers (endpoint)"
        "Resources (projetos avulso)"
        "Configurador de máquinas (out)"
        "teste fernando"
    )
    
    local folder=$(printf '%s\n' "${folders[@]}" | \
        fzf --prompt="Pasta de destino > " \
            --header="Selecione onde enviar o arquivo" \
            --height=10)
    
    [[ -z "$folder" ]] && return
    
    # Se escolheu "Outros", pedir nome personalizado
    if [[ "$folder" == "Outros" ]]; then
        echo
        read -p "📁 Nome da pasta: " folder </dev/tty
        [[ -z "$folder" ]] && return
    fi
    
    echo
    echo "📋 Resumo:"
    echo "  📄 Arquivo: $(basename "$file")"
    echo "  📁 Destino: $folder"
    echo "  💾 Tamanho: $(du -sh "$file" 2>/dev/null | cut -f1 || echo "N/A")"
    
    # Verificar se já foi enviado
    if [[ -f "$HISTORY_FILE" ]] && grep -q "^$file$" "$HISTORY_FILE" 2>/dev/null; then
        echo "  ⚠️ Este arquivo já foi enviado anteriormente"
    fi
    
    echo
    
    if confirm "Confirmar upload?"; then
        if perform_upload "$file" "$folder"; then
            # Adicionar ao histórico após sucesso
            add_to_history "$file" "file" "$folder"
        fi
    else
        echo "❌ Upload cancelado"
        sleep 1
    fi
}

# Upload rápido (do histórico) - MELHORADO
quick_upload() {
    if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
        clear_screen
        echo "📝 Nenhum histórico encontrado"
        echo "Use o navegador de arquivos primeiro"
        pause
        return
    fi
    
    # Pegar o último item do histórico
    local last_entry=$(tail -n 1 "$HISTORY_FILE")
    local item_type=$(echo "$last_entry" | cut -d'|' -f1)
    local item_path=$(echo "$last_entry" | cut -d'|' -f2)
    local last_destination=$(echo "$last_entry" | cut -d'|' -f3)
    
    if [[ "$item_type" == "file" ]] && [[ -f "$item_path" ]]; then
        clear_screen
        echo "⚡ Upload Rápido - Arquivo"
        echo "──────────────────────────"
        echo "📄 Arquivo: $(basename "$item_path")"
        echo "💾 Tamanho: $(du -sh "$item_path" 2>/dev/null | cut -f1 || echo "N/A")"
        echo "📁 Destino: $last_destination"
        echo
        
        if confirm "Enviar novamente para a mesma pasta?"; then
            if perform_upload "$item_path" "$last_destination"; then
                add_to_history "$item_path" "file" "$last_destination"
            fi
        fi
    elif [[ "$item_type" == "folder" ]] && [[ -d "$item_path" ]]; then
        clear_screen
        echo "⚡ Upload Rápido - Pasta"
        echo "───────────────────────"
        echo "📂 Pasta: $(basename "$item_path")"
        echo "💾 Tamanho: $(du -sh "$item_path" 2>/dev/null | cut -f1 || echo "N/A")"
        echo "📁 Destino: $last_destination"
        echo
        
        if confirm "Enviar pasta novamente para a mesma pasta?"; then
            if perform_folder_upload "$item_path" "$last_destination"; then
                add_to_history "$item_path" "folder" "$last_destination"
            fi
        fi
    else
        echo "❌ Último item do histórico não encontrado"
        pause
    fi
}


# Realizar upload (função auxiliar) - VERSÃO CORRIGIDA PARA GIT BASH
perform_upload() {
    local file="$1"
    local folder="$2"
    
    # Verificar se arquivo existe
    if [[ ! -f "$file" ]]; then
        echo "❌ Arquivo não encontrado: $file"
        return 1
    fi
    
    # Converter caminho para formato correto baseado no ambiente
    local corrected_file="$file"
    
    # Detectar ambiente e aplicar formato correto para curl
    if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
        # Git Bash - usar formato C:/ que funciona com curl
        if [[ "$file" =~ ^/c/ ]]; then
            corrected_file=$(echo "$file" | sed 's|^/c|C:|')
        elif [[ "$file" =~ ^[A-Z]: ]]; then
            corrected_file=$(echo "$file" | sed 's|\\|/|g')
        fi
    elif [[ -d "/mnt/c" ]]; then
        # WSL - converter para /mnt/c/ se necessário
        if [[ "$file" =~ ^/c/ ]]; then
            corrected_file=$(echo "$file" | sed 's|^/c|/mnt/c|')
        elif [[ "$file" =~ ^[A-Z]: ]]; then
            corrected_file=$(echo "$file" | sed 's|^C:|/mnt/c|' | sed 's|\\|/|g')
        fi
    fi
    
    # Verificar se o arquivo corrigido existe
    if [[ ! -f "$corrected_file" ]]; then
        echo "❌ Arquivo não encontrado após correção de caminho: $corrected_file"
        echo "   Arquivo original: $file"
        return 1
    fi
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        echo "❌ Token não encontrado"
        return 1
    fi
    
    local filename=$(basename "$corrected_file")
    echo "🔄 Enviando $filename..."
    echo "📂 Caminho: $corrected_file"
    
    # Teste de leitura do arquivo
    echo "📋 Verificando arquivo:"
    if head -c 10 "$corrected_file" > /dev/null 2>&1; then
        echo "   ✅ Arquivo legível"
    else
        echo "   ❌ Não foi possível ler o arquivo"
        return 1
    fi
    
    # Realizar upload
    echo "📤 Enviando para servidor..."
    
    local response=$(curl -s -X POST \
        -H "Cookie: jwt_user=$token; user_jwt=$token" \
        -F "arquivo[]=@$corrected_file" \
        -F "pasta=$folder" \
        "$CONFIG_URL" 2>&1)
    
    local curl_exit=$?
    
    echo "🔍 Resultado:"
    echo "   Exit code: $curl_exit"
    
    # Verificar resultado
    if [[ $curl_exit -eq 0 ]]; then
        echo "   Resposta: ${response:0:100}..."
        
        if echo "$response" | grep -q "Arquivos enviados com sucesso"; then
            echo "✅ $filename - Upload realizado com sucesso!"
            return 0
        elif echo "$response" | grep -q "Usuário autenticado"; then
            echo "⚠️ $filename - Autenticado mas sem confirmação completa"
            return 0
        else
            echo "❌ $filename - Resposta inesperada do servidor"
            echo "🔍 Resposta completa:"
            echo "$response"
        fi
    else
        echo "❌ $filename - Erro no curl (exit code: $curl_exit)"
        if [[ $curl_exit -eq 26 ]]; then
            echo "   • Erro de leitura do arquivo"
            echo "   • Caminho original: $file"
            echo "   • Caminho corrigido: $corrected_file"
        fi
    fi
    
    pause
    return 1
}

# Realizar upload de pasta inteira
perform_folder_upload() {
    local folder="$1"
    local destination="$2"
    
    # Verificar se pasta existe
    if [[ ! -d "$folder" ]]; then
        echo "❌ Pasta não encontrada: $folder"
        return 1
    fi
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        echo "❌ Token não encontrado"
        return 1
    fi
    
    local folder_name=$(basename "$folder")
    echo "🔄 Enviando pasta: $folder_name"
    
    # Contar arquivos
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$folder" -type f -print0)
    local total_files=${#files[@]}
    local current=0
    local success=0
    local failed=0
    
    echo "📊 Total de arquivos: $total_files"
    echo "🚀 Iniciando upload..."
    echo
    
    # Upload de cada arquivo
    for file in "${files[@]}"; do
        ((current++))
        local rel_path=${file#$folder/}
        local filename=$(basename "$file")
            if [[ ! -f "$file" ]]; then
                echo "   ⚠️ Arquivo não encontrado: $file"
                ((failed++))
                continue
            fi
        # Corrigir caminho para curl
        local corrected_file="$file"
        if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
            if [[ "$file" =~ ^/c/ ]]; then
                corrected_file=$(echo "$file" | sed 's|^/c|C:|')
            elif [[ "$file" =~ ^[A-Z]: ]]; then
                corrected_file=$(echo "$file" | sed 's|\\|/|g')
            fi
        fi
        
        echo "[$current/$total_files] 📄 $filename"
        
        # Realizar upload
        local response=$(curl -s -X POST \
            -H "Cookie: jwt_user=$token; user_jwt=$token" \
            -F "arquivo[]=@$corrected_file" \
            -F "pasta=$destination" \
            "$CONFIG_URL" 2>&1)
        
        local curl_exit=$?
        
        echo "   📄 Arquivo: $file"
        echo "   🔧 Corrigido: $corrected_file"
        echo "   📤 Response: ${response:0:200}"

        if [[ $curl_exit -eq 0 ]]; then
            if echo "$response" | grep -q -E "(enviados com sucesso|upload.*sucesso|success)"; then
                echo "   ✅ Sucesso"
                ((success++))
            else
                echo "   ❌ Resposta não indica sucesso"
                echo "   📋 Resposta: $response"
                ((failed++))
            fi
        else
            echo "   ❌ Falhou (exit: $curl_exit)"
            ((failed++))
        fi
    done
    
    echo
    echo "📊 Resultado final:"
    echo "   ✅ Sucessos: $success"
    echo "   ❌ Falhas: $failed"
    echo "   📊 Total: $total_files"
    
    if [[ $success -gt 0 ]]; then
        echo "✅ Upload da pasta concluído!"
        pause
        return 0
    else
        echo "❌ Nenhum arquivo foi enviado com sucesso"
        pause
        return 1
    fi
}


#===========================================
# SINCRONIZAÇÃO
#===========================================

# Função para log de debug da sincronização
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

# Verificar se sincronização está ativa
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

# Parar sincronização
stop_sync() {
    echo "🛑 Parando sincronização..."
    
    # Parar processo pelo PID
    if [[ -f "$SYNC_PID_FILE" ]]; then
        local pid=$(cat "$SYNC_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            sync_log "🛑 PARANDO DAEMON - PID: $pid"
            kill "$pid" 2>/dev/null
            sleep 2
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null
            fi
        fi
        rm -f "$SYNC_PID_FILE"
    fi
    
    # Limpar scripts temporários órfãos
    rm -f /tmp/upcode_sync_daemon_*.sh 2>/dev/null
    
    # Matar qualquer processo sync_daemon órfão
    pkill -f "sync_daemon" 2>/dev/null || true
    
    echo "✅ Sincronização parada"
    sync_log "✅ SINCRONIZAÇÃO PARADA PELO USUÁRIO"
}

# Obter informações da configuração de sincronização
get_sync_config() {
    if [[ -f "$SYNC_CONFIG_FILE" ]]; then
        local config=$(cat "$SYNC_CONFIG_FILE")
        local local_folder=$(echo "$config" | cut -d'|' -f1)
        local destination=$(echo "$config" | cut -d'|' -f2)
        local interval=$(echo "$config" | cut -d'|' -f3)
        echo "$local_folder|$destination|$interval"
    else
        echo "||"
    fi
}

# Sincronização em background
sync_daemon() {
    local local_folder="$1"
    local destination="$2"
    local interval="$3"
    
    sync_log "🚀 DAEMON INICIADO - Pasta: $(basename "$local_folder") → $destination (${interval}s)"
    
    while true; do
        # Verificar se processo pai ainda existe
        if ! ps -p $PPID > /dev/null 2>&1; then
            sync_log "⚠️ DAEMON TERMINADO - Processo pai não existe mais"
            exit 0
        fi
        
        sync_log "🔍 Verificando mudanças em: $(basename "$local_folder")"
        
        # Verificar mudanças
        check_and_sync_changes "$local_folder" "$destination"
        
        sleep "$interval"
    done
}

# Sincronização por estrutura completa de pasta
sync_complete_folder_structure() {
    local local_folder="$1"
    local destination="$2"
    
    if [[ ! -d "$local_folder" ]]; then
        sync_log "❌ ERRO - Pasta não encontrada: $local_folder"
        return 1
    fi
    
    sync_log "📁 ENVIANDO ESTRUTURA COMPLETA DA PASTA"
    sync_log "   🎯 Origem: $local_folder"
    sync_log "   🎯 Destino: $destination"
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        sync_log "❌ ERRO - Token não encontrado"
        return 1
    fi
    
# Sincronização por estrutura completa de pasta - VERSÃO OTIMIZADA
sync_complete_folder_structure() {
    local local_folder="$1"
    local destination="$2"
    
    if [[ ! -d "$local_folder" ]]; then
        sync_log "❌ ERRO - Pasta não encontrada: $local_folder"
        return 1
    fi
    
    sync_log "📁 UPLOAD COMPLETO - INÍCIO"
    sync_log "   📂 Origem: $local_folder"
    sync_log "   🎯 Destino: $destination"
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        sync_log "❌ ERRO - Token não encontrado"
        return 1
    fi
    
    # Usar a mesma lógica do perform_folder_upload que já funciona
    sync_log "🔍 COLETANDO ARQUIVOS COM A MESMA LÓGICA DO UPLOAD MANUAL..."
    
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$local_folder" -type f -print0)
    
    local total_files=${#files[@]}
    local success=0
    local failed=0
    
    sync_log "📊 TOTAL DE ARQUIVOS ENCONTRADOS: $total_files"
    
    if [[ $total_files -eq 0 ]]; then
        sync_log "⚠️ Nenhum arquivo encontrado"
        return 1
    fi
    
    sync_log "� INICIANDO UPLOAD DE TODOS OS ARQUIVOS..."
    
    # Upload de cada arquivo (como no perform_folder_upload)
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local relative_path="${file#$local_folder/}"
        
        # Verificar se arquivo existe
        if [[ ! -f "$file" ]]; then
            sync_log "⚠️ ARQUIVO NÃO ENCONTRADO: $file"
            ((failed++))
            continue
        fi
        
        # Corrigir caminho para curl
        local corrected_file="$file"
        if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
            if [[ "$file" =~ ^/c/ ]]; then
                corrected_file=$(echo "$file" | sed 's|^/c|C:|')
            elif [[ "$file" =~ ^[A-Z]: ]]; then
                corrected_file=$(echo "$file" | sed 's|\\|/|g')
            fi
        fi
        
        sync_log "📤 ENVIANDO ($((success + failed + 1))/$total_files): $relative_path"
        
        # Upload usando a mesma lógica que funciona
        local response=$(curl -s -X POST \
            -H "Cookie: jwt_user=$token; user_jwt=$token" \
            -F "arquivo[]=@$corrected_file" \
            -F "pasta=$destination" \
            "$CONFIG_URL" 2>&1)
        
        local curl_exit=$?
        
        if [[ $curl_exit -eq 0 ]] && echo "$response" | grep -q -E "(enviados com sucesso|upload.*sucesso|success)"; then
            sync_log "✅ SUCESSO: $relative_path"
            ((success++))
        else
            sync_log "❌ FALHA: $relative_path (Exit: $curl_exit)"
            sync_log "   📋 Response: ${response:0:100}..."
            ((failed++))
        fi
    done
    
    sync_log "� RESULTADO FINAL DO UPLOAD COMPLETO:"
    sync_log "   ✅ Sucessos: $success"
    sync_log "   ❌ Falhas: $failed" 
    sync_log "   📊 Total: $total_files"
    
    if [[ $success -gt 0 ]]; then
        sync_log "✅ UPLOAD COMPLETO CONCLUÍDO COM SUCESSO!"
        return 0
    else
        sync_log "❌ UPLOAD COMPLETO FALHOU - NENHUM ARQUIVO ENVIADO"
        return 1
    fi
}
}

# Verificar e sincronizar mudanças - VERSÃO COM UPLOAD COMPLETO
check_and_sync_changes() {
    local local_folder="$1"
    local destination="$2"
    
    if [[ ! -d "$local_folder" ]]; then
        sync_log "❌ ERRO - Pasta não encontrada: $local_folder"
        return 1
    fi
    
    sync_log "📂 INICIANDO VERIFICAÇÃO: $(basename "$local_folder")"
    sync_log "🎯 DESTINO: $destination"
    
    # Carregar cache anterior
    local old_cache=""
    if [[ -f "$SYNC_CACHE_FILE" ]]; then
        old_cache=$(cat "$SYNC_CACHE_FILE")
        sync_log "📋 Cache anterior carregado: $(echo "$old_cache" | wc -l) entradas"
    else
        sync_log "📋 Primeira sincronização - sem cache anterior"
    fi
    
    # Gerar cache atual com informações detalhadas
    sync_log "🔍 ESCANEANDO ARQUIVOS..."
    local current_cache=""
    local file_count=0
    
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            local timestamp=$(stat -c "%Y" "$file" 2>/dev/null || echo "0")
            local size=$(stat -c "%s" "$file" 2>/dev/null || echo "0")
            local hash=$(echo "$size-$timestamp" | md5sum | cut -d' ' -f1)
            
            current_cache+="$file|$timestamp|$size|$hash"$'\n'
            ((file_count++))
            
            # Log para arquivos em subpastas
            local relative_path="${file#$local_folder/}"
            if [[ "$relative_path" == *"/"* ]]; then
                local subdir=$(dirname "$relative_path")
                sync_log "📁 SUBPASTA: $subdir/$(basename "$file")"
            fi
        fi
    done < <(find "$local_folder" -type f -print0 2>/dev/null)
    
    sync_log "📊 TOTAL DE ARQUIVOS ENCONTRADOS: $file_count"
    
    # Analisar mudanças
    local files_to_sync=()
    local new_files=0
    local modified_files=0
    local renamed_files=0
    
    # Detectar arquivos novos e modificados
    while IFS='|' read -r file_path timestamp size hash; do
        [[ -z "$file_path" ]] && continue
        
        local old_entry=$(echo "$old_cache" | grep "^$file_path|")
        if [[ -n "$old_entry" ]]; then
            local old_timestamp=$(echo "$old_entry" | cut -d'|' -f2)
            local old_hash=$(echo "$old_entry" | cut -d'|' -f4)
            
            if [[ "$hash" != "$old_hash" ]]; then
                files_to_sync+=("$file_path")
                sync_log "✏️ ARQUIVO MODIFICADO: $(basename "$file_path")"
                sync_log "   � Mudança: $old_timestamp → $timestamp"
                ((modified_files++))
            fi
        else
            # Verificar se é renomeação (mesmo hash em local diferente)
            local old_file_with_same_hash=$(echo "$old_cache" | grep "|$hash$" | head -1)
            if [[ -n "$old_file_with_same_hash" ]]; then
                local old_path=$(echo "$old_file_with_same_hash" | cut -d'|' -f1)
                if [[ ! -f "$old_path" ]]; then
                    sync_log "🔄 ARQUIVO RENOMEADO: $(basename "$old_path") → $(basename "$file_path")"
                    ((renamed_files++))
                fi
            else
                sync_log "🆕 ARQUIVO NOVO: $(basename "$file_path")"
                ((new_files++))
            fi
            files_to_sync+=("$file_path")
        fi
    done <<< "$current_cache"
    
    # Detectar arquivos removidos
    local removed_files=0
    while IFS='|' read -r old_file old_timestamp old_size old_hash; do
        [[ -z "$old_file" ]] && continue
        if [[ ! -f "$old_file" ]]; then
            # Verificar se não foi renomeado
            local same_hash_exists=$(echo "$current_cache" | grep "|$old_hash$")
            if [[ -z "$same_hash_exists" ]]; then
                sync_log "🗑️ ARQUIVO REMOVIDO: $(basename "$old_file")"
                ((removed_files++))
            fi
        fi
    done <<< "$old_cache"
    
    sync_log "📈 RESUMO DAS MUDANÇAS:"
    sync_log "   🆕 Novos: $new_files"
    sync_log "   ✏️ Modificados: $modified_files"
    sync_log "   🔄 Renomeados: $renamed_files"
    sync_log "   🗑️ Removidos: $removed_files"
    
    # Sincronizar arquivos
    if [[ ${#files_to_sync[@]} -gt 0 ]]; then
        sync_log "� INICIANDO ENVIO DE ${#files_to_sync[@]} ARQUIVO(S)"
        echo "[$(date '+%H:%M:%S')] � Enviando ${#files_to_sync[@]} arquivo(s)..."
        
        local success_count=0
        local fail_count=0
        
        for file in "${files_to_sync[@]}"; do
            local filename=$(basename "$file")
            local relative_path="${file#$local_folder/}"
            
            sync_log "📤 PROCESSANDO: $relative_path"
            
            if sync_single_file_enhanced "$file" "$destination" "$local_folder"; then
                echo "[$(date '+%H:%M:%S')] ✅ $filename"
                sync_log "✅ SUCESSO: $relative_path"
                ((success_count++))
            else
                echo "[$(date '+%H:%M:%S')] ❌ $filename"
                sync_log "❌ FALHA: $relative_path"
                ((fail_count++))
            fi
        done
        
        sync_log "📊 RESULTADO FINAL - ✅ Sucessos: $success_count | ❌ Falhas: $fail_count"
        
        # Atualizar cache apenas se houve sucessos
        if [[ $success_count -gt 0 ]]; then
            echo "$current_cache" > "$SYNC_CACHE_FILE"
            sync_log "💾 Cache atualizado com $file_count arquivo(s)"
        fi
    else
        sync_log "😴 NENHUMA MUDANÇA DETECTADA"
    fi
}

# Sincronizar um único arquivo - VERSÃO MELHORADA
sync_single_file_enhanced() {
    local file="$1"
    local destination="$2"
    local local_folder="$3"
    
    if [[ ! -f "$file" ]]; then
        sync_log "❌ ERRO - Arquivo não encontrado: $file"
        return 1
    fi
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        sync_log "❌ ERRO - Token não encontrado"
        return 1
    fi
    
    # Calcular caminho de destino
    local final_destination="$destination"
    local relative_path=""
    local is_subfolder=false
    
    if [[ -n "$local_folder" ]]; then
        # Normalizar caminhos
        local norm_local=$(realpath "$local_folder" 2>/dev/null || echo "$local_folder")
        local norm_file=$(realpath "$file" 2>/dev/null || echo "$file")
        
        # Extrair caminho relativo
        if [[ "$norm_file" == "$norm_local"* ]]; then
            relative_path="${norm_file#$norm_local/}"
            local relative_dir=$(dirname "$relative_path")
            
            if [[ "$relative_dir" != "." && -n "$relative_dir" ]]; then
                final_destination="$destination/$relative_dir"
                is_subfolder=true
                sync_log "📁 SUBPASTA DETECTADA:"
                sync_log "   🔗 Caminho relativo: $relative_path"
                sync_log "   📂 Pasta destino: $final_destination"
            fi
        fi
    fi
    
    # Converter caminho do arquivo para curl
    local corrected_file="$file"
    if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
        if [[ "$file" =~ ^/c/ ]]; then
            corrected_file=$(echo "$file" | sed 's|^/c|C:|')
        elif [[ "$file" =~ ^[A-Z]: ]]; then
            corrected_file=$(echo "$file" | sed 's|\\|/|g')
        fi
    fi
    
    sync_log "📡 TENTATIVA DE UPLOAD:"
    sync_log "   📄 Arquivo: $(basename "$file")"
    sync_log "   🎯 Destino: $final_destination"
    sync_log "   📂 Subpasta: $([ "$is_subfolder" = true ] && echo "SIM" || echo "NÃO")"
    
    # Tentar upload
    local response=$(curl -s -X POST \
        -H "Cookie: jwt_user=$token; user_jwt=$token" \
        -F "arquivo[]=@$corrected_file" \
        -F "pasta=$final_destination" \
        "$CONFIG_URL" 2>&1)
    
    local curl_exit=$?
    
    sync_log "📋 RESULTADO DO CURL: Exit=$curl_exit"
    
    # Verificar sucesso
    if [[ $curl_exit -eq 0 ]]; then
        if echo "$response" | grep -q -i -E "(enviados com sucesso|upload.*sucesso|success|uploaded)"; then
            sync_log "✅ UPLOAD REALIZADO COM SUCESSO!"
            if [[ "$is_subfolder" = true ]]; then
                sync_log "   📁 Arquivo enviado para subpasta: $final_destination"
            fi
            return 0
        else
            sync_log "❌ SERVIDOR REJEITOU O UPLOAD"
            sync_log "   📋 Response: $response"
            
            # Se é subpasta, tentar fallback para pasta raiz
            if [[ "$is_subfolder" = true ]]; then
                sync_log "🔄 TENTANDO FALLBACK PARA PASTA RAIZ..."
                
                local fallback_response=$(curl -s -X POST \
                    -H "Cookie: jwt_user=$token; user_jwt=$token" \
                    -F "arquivo[]=@$corrected_file" \
                    -F "pasta=$destination" \
                    "$CONFIG_URL" 2>&1)
                
                if echo "$fallback_response" | grep -q -i -E "(enviados com sucesso|upload.*sucesso|success|uploaded)"; then
                    sync_log "⚠️ FALLBACK SUCESSO - Arquivo enviado para pasta raiz"
                    sync_log "   ℹ️ MOTIVO: Servidor pode não suportar criação automática de subpastas"
                    return 0
                else
                    sync_log "❌ FALLBACK TAMBÉM FALHOU: $fallback_response"
                fi
            fi
            return 1
        fi
    else
        sync_log "❌ ERRO NO CURL - Exit code: $curl_exit"
        sync_log "   📋 Output: $response"
        return 1
    fi
}

# Sincronizar um único arquivo (versão silenciosa) - MANTER PARA COMPATIBILIDADE
sync_single_file() {
    local file="$1"
    local destination="$2"
    local local_folder="$3"  # Pasta base para calcular caminho relativo
    
    sync_log "🔧 TENTANDO UPLOAD: $(basename "$file")"
    
    if [[ ! -f "$file" ]]; then
        sync_log "❌ ERRO - Arquivo não encontrado: $file"
        return 1
    fi
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
        sync_log "🔑 Token obtido do arquivo"
    fi
    
    if [[ -z "$token" ]]; then
        sync_log "❌ ERRO - Token não encontrado ou vazio"
        return 1
    fi
    
    # Calcular pasta de destino com estrutura de subpastas
    local final_destination="$destination"
    if [[ -n "$local_folder" ]]; then
        # Normalizar caminhos para evitar problemas
        local normalized_local=$(echo "$local_folder" | sed 's|/*$||')  # Remove trailing slashes
        local normalized_file="$file"
        
        sync_log "🔧 DEBUG - Local normalizado: $normalized_local"
        sync_log "🔧 DEBUG - Arquivo: $normalized_file"
        
        # Extrair caminho relativo
        if [[ "$normalized_file" == "$normalized_local"/* ]]; then
            local relative_path="${normalized_file#$normalized_local/}"
            local relative_dir=$(dirname "$relative_path")
            
            sync_log "🔧 DEBUG - Caminho relativo: $relative_path"
            sync_log "🔧 DEBUG - Dir relativo: $relative_dir"
            
            if [[ "$relative_dir" != "." && "$relative_dir" != "/" && -n "$relative_dir" ]]; then
                final_destination="$destination/$relative_dir"
                sync_log "📁 SUBPASTA DETECTADA: $relative_dir → $final_destination"
            else
                sync_log "📄 ARQUIVO NA RAIZ: $final_destination"
            fi
        else
            sync_log "⚠️ ERRO - Arquivo fora da pasta base: $normalized_file não está em $normalized_local"
        fi
    else
        sync_log "⚠️ LOCAL_FOLDER está vazio - usando destino original"
    fi
    
    # Converter caminho
    local corrected_file="$file"
    if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
        if [[ "$file" =~ ^/c/ ]]; then
            corrected_file=$(echo "$file" | sed 's|^/c|C:|')
            sync_log "🔄 Convertendo caminho: $file → $corrected_file"
        elif [[ "$file" =~ ^[A-Z]: ]]; then
            corrected_file=$(echo "$file" | sed 's|\\|/|g')
            sync_log "🔄 Normalizando caminho: $file → $corrected_file"
        fi
    fi
    
    sync_log "📡 Fazendo requisição HTTP para: $final_destination"
    
    # Upload silencioso
    local response=$(curl -s -X POST \
        -H "Cookie: jwt_user=$token; user_jwt=$token" \
        -F "arquivo[]=@$corrected_file" \
        -F "pasta=$final_destination" \
        "$CONFIG_URL" 2>&1)
    
    local curl_exit=$?
    
    sync_log "📋 Curl exit code: $curl_exit"
    sync_log "📋 Response completa: $response"
    
    if [[ $curl_exit -eq 0 ]]; then
        if echo "$response" | grep -q -E "(enviados com sucesso|upload.*sucesso|success)"; then
            sync_log "✅ UPLOAD CONCLUÍDO COM SUCESSO: $(basename "$file") → $final_destination"
            return 0
        else
            sync_log "❌ UPLOAD FALHOU - Servidor rejeitou. Response: $response"
            # Verificar se é problema de subpasta
            if [[ "$final_destination" != "$destination" ]]; then
                sync_log "🔍 TENTATIVA: Pode ser problema de subpasta. Tentando enviar para pasta raiz..."
                # Tentar enviar para pasta raiz como fallback
                local fallback_response=$(curl -s -X POST \
                    -H "Cookie: jwt_user=$token; user_jwt=$token" \
                    -F "arquivo[]=@$corrected_file" \
                    -F "pasta=$destination" \
                    "$CONFIG_URL" 2>&1)
                
                if echo "$fallback_response" | grep -q -E "(enviados com sucesso|upload.*sucesso|success)"; then
                    sync_log "⚠️ FALLBACK SUCESSO: Arquivo enviado para pasta raiz (servidor não suporta subpastas?)"
                    return 0
                else
                    sync_log "❌ FALLBACK FALHOU: $fallback_response"
                fi
            fi
            return 1
        fi
    else
        sync_log "❌ UPLOAD FALHOU - Exit: $curl_exit, Response: $response"
        return 1
    fi
}

# Menu de sincronização
sync_menu() {
    while true; do
        clear_screen
        echo "🔄 Sincronização de Pasta"
        echo "════════════════════════"
        
        # Verificar status atual
        local is_running=false
        if is_sync_running; then
            is_running=true
            echo "🟢 Status: ATIVO"
        else
            echo "🔴 Status: INATIVO"
        fi
        
        # Mostrar configuração atual
        local config=$(get_sync_config)
        local local_folder=$(echo "$config" | cut -d'|' -f1)
        local destination=$(echo "$config" | cut -d'|' -f2)
        local interval=$(echo "$config" | cut -d'|' -f3)
        
        echo "─────────────────────────"
        if [[ -n "$local_folder" && -n "$destination" ]]; then
            echo "📁 Pasta local: $(basename "$local_folder")"
            echo "🎯 Destino: $destination"
            echo "⏱️ Intervalo: ${interval:-30}s"
        else
            echo "⚠️ Nenhuma sincronização configurada"
        fi
        echo
        
        # Opções do menu
        local sync_options=()
        
        if [[ -n "$local_folder" && -n "$destination" ]]; then
            if $is_running; then
                sync_options+=("stop|⏹️ Parar Sincronização")
                sync_options+=("status|📊 Ver Status Detalhado")
                sync_options+=("debug|🔍 Ver Log de Debug")
            else
                sync_options+=("start|▶️ Iniciar Sincronização")
            fi
            sync_options+=("reconfig|🔧 Reconfigurar")
        else
            sync_options+=("config|⚙️ Configurar Sincronização")
        fi
        
        sync_options+=("manual|🔄 Sincronização Manual")
        sync_options+=("force|💪 Forçar Reenvio Completo")
        sync_options+=("complete|📁 Upload Completo da Estrutura")
        sync_options+=("back|🔙 Voltar ao Menu Principal")
        
        local choice=$(printf '%s\n' "${sync_options[@]}" | \
            sed 's/^[^|]*|//' | \
            fzf --prompt="Sincronização > " \
                --header="Gerencie a sincronização automática de pastas" \
                --height=12)
        
        [[ -z "$choice" ]] && return
        
        # Processar escolha
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
                    "debug")
                        show_debug_log
                        ;;
                    "manual")
                        manual_sync
                        ;;
                    "force")
                        force_complete_resync
                        ;;
                    "complete")
                        complete_structure_upload
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

# Configurar sincronização para uma pasta específica (chamada do navegador)
setup_sync_for_folder() {
    local selected_folder="$1"
    
    clear_screen
    echo "🔄 Configurar Sincronização Rápida"
    echo "═════════════════════════════════"
    echo "📁 Pasta selecionada: $(basename "$selected_folder")"
    echo "🔗 Caminho: $selected_folder"
    echo
    
    # Verificar se já existe configuração
    local config=$(get_sync_config)
    local current_folder=$(echo "$config" | cut -d'|' -f1)
    
    if [[ -n "$current_folder" ]]; then
        echo "⚠️  Já existe uma sincronização configurada:"
        echo "   📁 Pasta atual: $(basename "$current_folder")"
        echo
        
        if ! confirm "Substituir configuração existente?"; then
            echo "❌ Operação cancelada"
            sleep 2
            return
        fi
        
        # Parar sincronização atual se estiver rodando
        if is_sync_running; then
            echo "🛑 Parando sincronização atual..."
            stop_sync
        fi
    fi
    
    # Selecionar destino no servidor
    echo "🎯 Selecionar pasta de destino no servidor..."
    local folders=(
        "Cutprefers (endpoint)"
        "Resources (projetos avulso)"
        "Configurador de máquinas (out)"
        "teste fernando"
    )
    
    local destination=$(printf '%s\n' "${folders[@]}" | \
        fzf --prompt="Destino > " \
            --header="Selecione onde sincronizar os arquivos" \
            --height=10)
    
    if [[ -z "$destination" ]]; then
        echo "❌ Configuração cancelada"
        sleep 2
        return
    fi
    
    # Selecionar intervalo
    echo
    echo "⏱️ Selecionar intervalo de sincronização..."
    local intervals=(
        "01|⚡ 1 segundos (tempo real)"
        "10|⚡ 10 segundos (tempo real)"
        "30|🔄 30 segundos (recomendado)"
        "60|⏰ 1 minuto (econômico)"
        "300|🐌 5 minutos (muito econômico)"
    )
    
    local interval_choice=$(printf '%s\n' "${intervals[@]}" | \
        sed 's/^[^|]*|//' | \
        fzf --prompt="Intervalo > " \
            --header="Frequência de verificação de mudanças" \
            --height=8)
    
    if [[ -z "$interval_choice" ]]; then
        echo "❌ Configuração cancelada"
        sleep 2
        return
    fi
    
    # Extrair o valor numérico do intervalo
    local interval=""
    for item in "${intervals[@]}"; do
        if [[ "$item" == *"|$interval_choice" ]]; then
            interval=$(echo "$item" | cut -d'|' -f1)
            break
        fi
    done
    
    # Salvar configuração
    echo "$selected_folder|$destination|$interval" > "$SYNC_CONFIG_FILE"
    
    # Criar cache inicial
    if [[ -d "$selected_folder" ]]; then
        find "$selected_folder" -type f -printf '%p|%T@\n' 2>/dev/null | sort > "$SYNC_CACHE_FILE"
    fi
    
    clear_screen
    echo "✅ Sincronização Configurada!"
    echo "════════════════════════════"
    echo "📁 Pasta: $(basename "$selected_folder")"
    echo "🎯 Destino: $destination"
    echo "⏱️ Intervalo: $interval segundos"
    echo
    
        # Perguntar se quer iniciar imediatamente
        if confirm "🚀 Iniciar sincronização automática agora?"; then
            # Limpar log anterior
            > "$SYNC_LOG_FILE"
            sync_log "🎯 SINCRONIZAÇÃO INICIADA VIA NAVEGADOR"
            
            # Criar script temporário para o daemon
            local daemon_script="/tmp/upcode_sync_daemon_$$.sh"
            cat > "$daemon_script" << 'EOF'
#!/bin/bash

# Recriar as funções necessárias
sync_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$HOME/.upcode_sync_debug.log"
    
    # Manter apenas as últimas 100 linhas do log
    if [[ -f "$HOME/.upcode_sync_debug.log" ]]; then
        tail -n 100 "$HOME/.upcode_sync_debug.log" > "$HOME/.upcode_sync_debug.log.tmp"
        mv "$HOME/.upcode_sync_debug.log.tmp" "$HOME/.upcode_sync_debug.log"
    fi
}

sync_single_file() {
    local file="$1"
    local destination="$2"
    local CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
    local TOKEN_FILE="$HOME/.upcode_token"
    
    sync_log "🔧 TENTANDO UPLOAD: $(basename "$file")"
    
    if [[ ! -f "$file" ]]; then
        sync_log "❌ ERRO - Arquivo não encontrado: $file"
        return 1
    fi
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
        sync_log "🔑 Token obtido do arquivo"
    fi
    
    if [[ -z "$token" ]]; then
        sync_log "❌ ERRO - Token não encontrado ou vazio"
        return 1
    fi
    
    # Converter caminho
    local corrected_file="$file"
    if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
        if [[ "$file" =~ ^/c/ ]]; then
            corrected_file=$(echo "$file" | sed 's|^/c|C:|')
            sync_log "🔄 Convertendo caminho: $file → $corrected_file"
        elif [[ "$file" =~ ^[A-Z]: ]]; then
            corrected_file=$(echo "$file" | sed 's|\\|/|g')
            sync_log "🔄 Normalizando caminho: $file → $corrected_file"
        fi
    fi
    
    sync_log "📡 Fazendo requisição HTTP..."
    
    # Upload silencioso
    local response=$(curl -s -X POST \
        -H "Cookie: jwt_user=$token; user_jwt=$token" \
        -F "arquivo[]=@$corrected_file" \
        -F "pasta=$destination" \
        "$CONFIG_URL" 2>&1)
    
    local curl_exit=$?
    
    sync_log "📋 Curl exit code: $curl_exit"
    sync_log "📋 Response: ${response:0:200}..."
    
    if [[ $curl_exit -eq 0 ]] && echo "$response" | grep -q -E "(enviados com sucesso|upload.*sucesso|success)"; then
        sync_log "✅ UPLOAD CONCLUÍDO COM SUCESSO: $(basename "$file")"
        return 0
    else
        sync_log "❌ UPLOAD FALHOU - Exit: $curl_exit, Response: $response"
        return 1
    fi
}

check_and_sync_changes() {
    local local_folder="$1"
    local destination="$2"
    local SYNC_CACHE_FILE="$HOME/.upcode_sync_cache"
    
    if [[ ! -d "$local_folder" ]]; then
        sync_log "❌ ERRO - Pasta não encontrada: $local_folder"
        return 1
    fi
    
    local current_cache=""
    local old_cache=""
    
    sync_log "📂 Analisando pasta: $(basename "$local_folder")"
    
    # Carregar cache anterior
    if [[ -f "$SYNC_CACHE_FILE" ]]; then
        old_cache=$(cat "$SYNC_CACHE_FILE")
    fi
    
    # Gerar cache atual
    current_cache=$(find "$local_folder" -type f -printf '%p|%T@\n' 2>/dev/null | sort)
    local total_files=$(echo "$current_cache" | grep -c . || echo 0)
    sync_log "📊 Arquivos encontrados: $total_files"
    
    # Comparar e encontrar arquivos modificados
    local files_to_sync=()
    
    while IFS='|' read -r file_path file_time; do
        [[ -z "$file_path" ]] && continue
        
        local old_time=$(echo "$old_cache" | grep "^$file_path|" | cut -d'|' -f2)
        
        if [[ -z "$old_time" ]] || [[ "$file_time" != "$old_time" ]]; then
            files_to_sync+=("$file_path")
            if [[ -z "$old_time" ]]; then
                sync_log "🆕 NOVO ARQUIVO: $(basename "$file_path")"
            else
                sync_log "✏️ MODIFICADO: $(basename "$file_path")"
            fi
        fi
    done <<< "$current_cache"
    
    # Sincronizar arquivos modificados
    if [[ ${#files_to_sync[@]} -gt 0 ]]; then
        sync_log "🔄 INICIANDO SYNC - ${#files_to_sync[@]} arquivo(s) para enviar"
        
        local success_count=0
        local fail_count=0
        
        for file in "${files_to_sync[@]}"; do
            sync_log "📤 ENVIANDO: $(basename "$file")"
            if sync_single_file "$file" "$destination"; then
                sync_log "✅ SUCESSO: $(basename "$file")"
                ((success_count++))
            else
                sync_log "❌ FALHA: $(basename "$file")"
                ((fail_count++))
            fi
        done
        
        sync_log "📊 RESULTADO - Sucessos: $success_count, Falhas: $fail_count"
    else
        sync_log "✨ NENHUMA MUDANÇA DETECTADA"
    fi
    
    # Atualizar cache
    echo "$current_cache" > "$SYNC_CACHE_FILE"
    sync_log "💾 Cache atualizado com $total_files arquivo(s)"
}

# Daemon principal
sync_daemon() {
    local local_folder="$1"
    local destination="$2" 
    local interval="$3"
    
    sync_log "🚀 DAEMON INICIADO - Pasta: $(basename "$local_folder") → $destination (${interval}s)"
    
    while true; do
        sync_log "🔍 Verificando mudanças em: $(basename "$local_folder")"
        
        # Verificar mudanças
        check_and_sync_changes "$local_folder" "$destination"
        
        sync_log "😴 Aguardando ${interval}s até próxima verificação..."
        sleep "$interval"
    done
}

# Executar daemon
sync_daemon "$@"
EOF
            
            chmod +x "$daemon_script"
            
            # Iniciar daemon em background usando o script
            nohup "$daemon_script" "$selected_folder" "$destination" "$interval" > /dev/null 2>&1 &
            local daemon_pid=$!
            
            echo "$daemon_pid" > "$SYNC_PID_FILE"
            
            echo "✅ Sincronização iniciada!"
            echo "📡 Monitoramento automático ativo em background"
            echo "💡 Use 'Menu → Sincronização → Ver Status' para debug"
        else
            echo "💡 Use 'Menu → Sincronização → Iniciar' para ativar depois"
        fi
        
        pause
}

# Configurar sincronização
configure_sync() {
    clear_screen
    echo "⚙️ Configuração de Sincronização"
    echo "═══════════════════════════════"
    echo
    
    # Selecionar pasta local
    echo "📁 Selecionar pasta local para sincronizar..."
    local selected_folder=$(select_folder_for_sync)
    
    if [[ -z "$selected_folder" ]]; then
        echo "❌ Configuração cancelada"
        sleep 2
        return
    fi
    
    # Selecionar destino no servidor
    echo
    echo "🎯 Selecionar pasta de destino no servidor..."
    local folders=(
        "Cutprefers (endpoint)"
        "Resources (projetos avulso)"
        "Configurador de máquinas (out)"
        "teste fernando"
    )
    
    local destination=$(printf '%s\n' "${folders[@]}" | \
        fzf --prompt="Destino > " \
            --header="Selecione onde sincronizar os arquivos" \
            --height=10)
    
    if [[ -z "$destination" ]]; then
        echo "❌ Configuração cancelada"
        sleep 2
        return
    fi
    
    # Selecionar intervalo
    echo
    echo "⏱️ Selecionar intervalo de sincronização..."
    local intervals=(
        "10|⚡ 10 segundos (tempo real)"
        "30|🔄 30 segundos (recomendado)"
        "60|⏰ 1 minuto (econômico)"
        "300|🐌 5 minutos (muito econômico)"
    )
    
    local interval_choice=$(printf '%s\n' "${intervals[@]}" | \
        sed 's/^[^|]*|//' | \
        fzf --prompt="Intervalo > " \
            --header="Frequência de verificação de mudanças" \
            --height=8)
    
    if [[ -z "$interval_choice" ]]; then
        echo "❌ Configuração cancelada"
        sleep 2
        return
    fi
    
    # Extrair o valor numérico do intervalo
    local interval=""
    for item in "${intervals[@]}"; do
        if [[ "$item" == *"|$interval_choice" ]]; then
            interval=$(echo "$item" | cut -d'|' -f1)
            break
        fi
    done
    
    # Salvar configuração
    echo "$selected_folder|$destination|$interval" > "$SYNC_CONFIG_FILE"
    
    # Criar cache inicial
    if [[ -d "$selected_folder" ]]; then
        find "$selected_folder" -type f -printf '%p|%T@\n' 2>/dev/null | sort > "$SYNC_CACHE_FILE"
    fi
    
    clear_screen
    echo "✅ Sincronização Configurada!"
    echo "════════════════════════════"
    echo "📁 Pasta: $(basename "$selected_folder")"
    echo "🎯 Destino: $destination"
    echo "⏱️ Intervalo: $interval segundos"
    echo
    echo "Use 'Iniciar Sincronização' para ativar o monitoramento automático."
    pause
}

# Seletor de pasta para sincronização
select_folder_for_sync() {
    local current_dir="${1:-$HOME}"
    
    # Se for Windows/WSL, começar em /mnt/c/Users se possível
    if [[ -d "/mnt/c/Users" && "$current_dir" == "$HOME" ]]; then
        current_dir="/mnt/c/Users"
    elif [[ ! -d "$current_dir" ]]; then
        current_dir="$HOME"
    fi
    
    while true; do
        clear_screen
        echo "📁 Selecionar Pasta para Sincronização"
        echo "📂 Atual: $current_dir"
        echo "─────────────────────────────────────"
        
        local items=()
        
        # Opção para voltar
        if [[ "$current_dir" != "/" && "$current_dir" != "/mnt/c" ]]; then
            items+=(".. [🔙 Voltar]")
        fi
        
        # Opção para selecionar pasta atual
        items+=("")
        items+=("SELECT_CURRENT||✅ SELECIONAR ESTA PASTA: $(basename "$current_dir")")
        items+=("")
        items+=("--- [📂 SUBPASTAS] ---")
        
        # Listar apenas diretórios
        local dir_count=0
        if [[ -r "$current_dir" ]]; then
            while IFS= read -r item; do
                [[ -z "$item" ]] && continue
                local full_path="$current_dir/$item"
                if [[ -d "$full_path" ]]; then
                    local file_count=$(find "$full_path" -type f 2>/dev/null | wc -l)
                    items+=("DIR|$full_path|📂 $item/ ($file_count arquivos)")
                    ((dir_count++))
                fi
            done < <(ls -1 "$current_dir" 2>/dev/null | head -30)
        fi
        
        items+=("")
        items+=("CANCEL||❌ Cancelar")
        
        echo "📊 Encontradas: $dir_count pastas"
        echo
        
        local choice=$(printf '%s\n' "${items[@]}" | \
            sed 's/^[^|]*|[^|]*|//' | \
            fzf --prompt="📁 Pasta > " \
                --header="Navegue até a pasta que deseja sincronizar" \
                --preview-window=hidden)
        
        [[ -z "$choice" ]] && return
        
        # Processar escolha
        for item in "${items[@]}"; do
            if [[ "$item" == *"|$choice" ]]; then
                local action=$(echo "$item" | cut -d'|' -f1)
                local path=$(echo "$item" | cut -d'|' -f2)
                
                case "$action" in
                    "..")
                        current_dir=$(dirname "$current_dir")
                        ;;
                    "DIR")
                        current_dir="$path"
                        ;;
                    "SELECT_CURRENT")
                        echo "$current_dir"
                        return
                        ;;
                    "CANCEL")
                        return
                        ;;
                esac
                break
            fi
        done
    done
}

# Iniciar sincronização
start_sync() {
    local config=$(get_sync_config)
    local local_folder=$(echo "$config" | cut -d'|' -f1)
    local destination=$(echo "$config" | cut -d'|' -f2)
    local interval=$(echo "$config" | cut -d'|' -f3)
    
    if [[ -z "$local_folder" || -z "$destination" ]]; then
        echo "❌ Sincronização não configurada"
        pause
        return
    fi
    
    if [[ ! -d "$local_folder" ]]; then
        echo "❌ Pasta local não encontrada: $local_folder"
        pause
        return
    fi
    
    if is_sync_running; then
        echo "⚠️ Sincronização já está ativa"
        pause
        return
    fi
    
    # Limpar log anterior
    > "$SYNC_LOG_FILE"
    sync_log "🎯 INICIANDO NOVA SESSÃO DE SINCRONIZAÇÃO"
    
    # Criar script temporário para o daemon
    local daemon_script="/tmp/upcode_sync_daemon_$$.sh"
    cat > "$daemon_script" << 'EOF'
#!/bin/bash

# Recriar as funções necessárias
sync_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$HOME/.upcode_sync_debug.log"
    
    # Manter apenas as últimas 100 linhas do log
    if [[ -f "$HOME/.upcode_sync_debug.log" ]]; then
        tail -n 100 "$HOME/.upcode_sync_debug.log" > "$HOME/.upcode_sync_debug.log.tmp"
        mv "$HOME/.upcode_sync_debug.log.tmp" "$HOME/.upcode_sync_debug.log"
    fi
}

sync_single_file() {
    local file="$1"
    local destination="$2"
    local CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
    local TOKEN_FILE="$HOME/.upcode_token"
    
    sync_log "🔧 TENTANDO UPLOAD: $(basename "$file")"
    
    if [[ ! -f "$file" ]]; then
        sync_log "❌ ERRO - Arquivo não encontrado: $file"
        return 1
    fi
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
        sync_log "🔑 Token obtido do arquivo"
    fi
    
    if [[ -z "$token" ]]; then
        sync_log "❌ ERRO - Token não encontrado ou vazio"
        return 1
    fi
    
    # Converter caminho
    local corrected_file="$file"
    if [[ -d "/c/Windows" ]] && [[ ! -d "/mnt/c" ]]; then
        if [[ "$file" =~ ^/c/ ]]; then
            corrected_file=$(echo "$file" | sed 's|^/c|C:|')
            sync_log "🔄 Convertendo caminho: $file → $corrected_file"
        elif [[ "$file" =~ ^[A-Z]: ]]; then
            corrected_file=$(echo "$file" | sed 's|\\|/|g')
            sync_log "🔄 Normalizando caminho: $file → $corrected_file"
        fi
    fi
    
    sync_log "📡 Fazendo requisição HTTP..."
    
    # Upload silencioso
    local response=$(curl -s -X POST \
        -H "Cookie: jwt_user=$token; user_jwt=$token" \
        -F "arquivo[]=@$corrected_file" \
        -F "pasta=$destination" \
        "$CONFIG_URL" 2>&1)
    
    local curl_exit=$?
    
    sync_log "📋 Curl exit code: $curl_exit"
    sync_log "📋 Response: ${response:0:200}..."
    
    if [[ $curl_exit -eq 0 ]] && echo "$response" | grep -q -E "(enviados com sucesso|upload.*sucesso|success)"; then
        sync_log "✅ UPLOAD CONCLUÍDO COM SUCESSO: $(basename "$file")"
        return 0
    else
        sync_log "❌ UPLOAD FALHOU - Exit: $curl_exit, Response: $response"
        return 1
    fi
}

check_and_sync_changes() {
    local local_folder="$1"
    local destination="$2"
    local SYNC_CACHE_FILE="$HOME/.upcode_sync_cache"
    
    if [[ ! -d "$local_folder" ]]; then
        sync_log "❌ ERRO - Pasta não encontrada: $local_folder"
        return 1
    fi
    
    local current_cache=""
    local old_cache=""
    
    sync_log "📂 Analisando pasta: $(basename "$local_folder")"
    
    # Carregar cache anterior
    if [[ -f "$SYNC_CACHE_FILE" ]]; then
        old_cache=$(cat "$SYNC_CACHE_FILE")
    fi
    
    # Gerar cache atual
    current_cache=$(find "$local_folder" -type f -printf '%p|%T@\n' 2>/dev/null | sort)
    local total_files=$(echo "$current_cache" | grep -c . || echo 0)
    sync_log "📊 Arquivos encontrados: $total_files"
    
    # Comparar e encontrar arquivos modificados
    local files_to_sync=()
    
    while IFS='|' read -r file_path file_time; do
        [[ -z "$file_path" ]] && continue
        
        local old_time=$(echo "$old_cache" | grep "^$file_path|" | cut -d'|' -f2)
        
        if [[ -z "$old_time" ]] || [[ "$file_time" != "$old_time" ]]; then
            files_to_sync+=("$file_path")
            if [[ -z "$old_time" ]]; then
                sync_log "🆕 NOVO ARQUIVO: $(basename "$file_path")"
            else
                sync_log "✏️ MODIFICADO: $(basename "$file_path")"
            fi
        fi
    done <<< "$current_cache"
    
    # Sincronizar arquivos modificados
    if [[ ${#files_to_sync[@]} -gt 0 ]]; then
        sync_log "🔄 INICIANDO SYNC - ${#files_to_sync[@]} arquivo(s) para enviar"
        
        local success_count=0
        local fail_count=0
        
        for file in "${files_to_sync[@]}"; do
            sync_log "📤 ENVIANDO: $(basename "$file")"
            if sync_single_file "$file" "$destination"; then
                sync_log "✅ SUCESSO: $(basename "$file")"
                ((success_count++))
            else
                sync_log "❌ FALHA: $(basename "$file")"
                ((fail_count++))
            fi
        done
        
        sync_log "📊 RESULTADO - Sucessos: $success_count, Falhas: $fail_count"
    else
        sync_log "✨ NENHUMA MUDANÇA DETECTADA"
    fi
    
    # Atualizar cache
    echo "$current_cache" > "$SYNC_CACHE_FILE"
    sync_log "💾 Cache atualizado com $total_files arquivo(s)"
}

# Daemon principal
sync_daemon() {
    local local_folder="$1"
    local destination="$2" 
    local interval="$3"
    
    sync_log "🚀 DAEMON INICIADO - Pasta: $(basename "$local_folder") → $destination (${interval}s)"
    
    while true; do
        sync_log "🔍 Verificando mudanças em: $(basename "$local_folder")"
        
        # Verificar mudanças
        check_and_sync_changes "$local_folder" "$destination"
        
        sync_log "😴 Aguardando ${interval}s até próxima verificação..."
        sleep "$interval"
    done
}

# Executar daemon
sync_daemon "$@"
EOF
    
    chmod +x "$daemon_script"
    
    # Iniciar daemon em background usando o script
    nohup "$daemon_script" "$local_folder" "$destination" "$interval" > /dev/null 2>&1 &
    local daemon_pid=$!
    
    echo "$daemon_pid" > "$SYNC_PID_FILE"
    
    echo "✅ Sincronização iniciada!"
    echo "📁 Pasta: $(basename "$local_folder")"
    echo "🎯 Destino: $destination"
    echo "⏱️ Intervalo: $interval segundos"
    echo
    echo "💡 Debug ativo: Use 'Ver Status Detalhado' para monitorar atividade"
    echo "A sincronização continuará rodando em background."
    pause
}

# Mostrar status da sincronização
show_sync_status() {
    clear_screen
    echo "📊 Status da Sincronização"
    echo "═════════════════════════"
    
    if ! is_sync_running; then
        echo "🔴 Sincronização não está ativa"
        
        # Mostrar últimas entradas do log mesmo se não estiver rodando
        if [[ -f "$SYNC_LOG_FILE" ]]; then
            echo
            echo "📋 Últimas atividades (arquivo de log):"
            echo "─────────────────────────────────────"
            tail -n 10 "$SYNC_LOG_FILE" | while IFS= read -r line; do
                echo "   $line"
            done
        fi
        pause
        return
    fi
    
    local config=$(get_sync_config)
    local local_folder=$(echo "$config" | cut -d'|' -f1)
    local destination=$(echo "$config" | cut -d'|' -f2)
    local interval=$(echo "$config" | cut -d'|' -f3)
    
    echo "🟢 Status: ATIVO"
    echo "📁 Pasta: $(basename "$local_folder")"
    echo "🎯 Destino: $destination"
    echo "⏱️ Intervalo: $interval segundos"
    echo
    
    # Mostrar estatísticas da pasta
    if [[ -d "$local_folder" ]]; then
        local file_count=$(find "$local_folder" -type f 2>/dev/null | wc -l)
        local dir_count=$(find "$local_folder" -type d 2>/dev/null | wc -l)
        local total_size=$(du -sh "$local_folder" 2>/dev/null | cut -f1 || echo "?")
        
        echo "📊 Estatísticas da pasta:"
        echo "   📄 Arquivos: $file_count"
        echo "   📁 Subpastas: $((dir_count - 1))"
        echo "   💾 Tamanho total: $total_size"
    fi
    
    # Mostrar log de atividade em tempo real
    if [[ -f "$SYNC_LOG_FILE" ]]; then
        echo
        echo "� Debug - Últimas 15 atividades:"
        echo "─────────────────────────────────"
        tail -n 15 "$SYNC_LOG_FILE" | while IFS= read -r line; do
            # Colorir diferentes tipos de log
            if [[ "$line" == *"✅"* ]]; then
                echo "   $line"  # Verde para sucesso
            elif [[ "$line" == *"❌"* ]]; then
                echo "   $line"  # Vermelho para erro
            elif [[ "$line" == *"🔄"* ]]; then
                echo "   $line"  # Azul para processo
            else
                echo "   $line"  # Normal
            fi
        done
        
        echo
        echo "💡 O log é atualizado em tempo real durante a sincronização"
        echo "🔄 Pressione Enter para atualizar ou Ctrl+C para sair"
    fi
    
    pause
}

# Mostrar log de debug da sincronização
show_debug_log() {
    clear_screen
    echo "🔍 Log de Debug da Sincronização"
    echo "═══════════════════════════════"
    
    if [[ ! -f "$SYNC_LOG_FILE" ]]; then
        echo "📝 Nenhum log de debug encontrado"
        echo "💡 O log será criado quando a sincronização for iniciada"
        pause
        return
    fi
    
    local log_size=$(wc -l < "$SYNC_LOG_FILE" 2>/dev/null || echo 0)
    echo "📊 Tamanho do log: $log_size linhas"
    echo "📁 Arquivo: $SYNC_LOG_FILE"
    echo
    
    if [[ $log_size -eq 0 ]]; then
        echo "📝 Log está vazio"
        pause
        return
    fi
    
    # Mostrar opções de visualização
    local debug_options=(
        "tail20|📄 Últimas 20 entradas"
        "tail50|📄 Últimas 50 entradas"
        "all|📄 Todo o log ($log_size linhas)"
        "follow|🔄 Seguir log em tempo real"
        "changes|🔍 Ver Mudanças Recentes"
        "clear|🗑️ Limpar log"
        "back|🔙 Voltar"
    )
    
    local choice=$(printf '%s\n' "${debug_options[@]}" | \
        sed 's/^[^|]*|//' | \
        fzf --prompt="Debug > " \
            --header="Visualizar log de atividade da sincronização" \
            --height=10)
    
    [[ -z "$choice" ]] && return
    
    # Processar escolha
    for option in "${debug_options[@]}"; do
        if [[ "$option" == *"|$choice" ]]; then
            local action=$(echo "$option" | cut -d'|' -f1)
            
            case "$action" in
                "tail20")
                    echo "📋 Últimas 20 entradas:"
                    echo "─────────────────────"
                    tail -n 20 "$SYNC_LOG_FILE"
                    pause
                    ;;
                "tail50")
                    echo "📋 Últimas 50 entradas:"
                    echo "─────────────────────"
                    tail -n 50 "$SYNC_LOG_FILE"
                    pause
                    ;;
                "all")
                    echo "📋 Log completo ($log_size linhas):"
                    echo "──────────────────────────────"
                    cat "$SYNC_LOG_FILE"
                    pause
                    ;;
                "follow")
                    echo "🔄 Seguindo log em tempo real (Ctrl+C para sair):"
                    echo "─────────────────────────────────────────────"
                    tail -f "$SYNC_LOG_FILE"
                    ;;
                "changes")
                    show_recent_changes
                    ;;
                "clear")
                    if confirm "Limpar todo o log de debug?"; then
                        > "$SYNC_LOG_FILE"
                        echo "✅ Log limpo!"
                        sleep 1
                    fi
                    ;;
                "back")
                    return
                    ;;
            esac
            break
        fi
    done
}

# Upload completo da estrutura preservando hierarquia
complete_structure_upload() {
    local config=$(get_sync_config)
    local local_folder=$(echo "$config" | cut -d'|' -f1)
    local destination=$(echo "$config" | cut -d'|' -f2)
    
    if [[ -z "$local_folder" || -z "$destination" ]]; then
        echo "❌ Sincronização não configurada"
        pause
        return
    fi
    
    clear_screen
    echo "📁 Upload Completo da Estrutura"
    echo "════════════════════════════════"
    echo "📂 Pasta origem: $(basename "$local_folder")"
    echo "🎯 Destino: $destination"
    echo
    echo "💡 VANTAGENS DESTA MODALIDADE:"
    echo "• Preserva estrutura completa de pastas"
    echo "• Envia tudo de uma vez (como funciona o upload manual)"
    echo "• Garante que subpastas sejam criadas no servidor"
    echo "• Mais eficiente para muitos arquivos"
    echo
    
    # Mostrar estatísticas
    if [[ -d "$local_folder" ]]; then
        local file_count=$(find "$local_folder" -type f 2>/dev/null | wc -l)
        local subdir_count=$(find "$local_folder" -type d 2>/dev/null | wc -l)
        local total_size=$(du -sh "$local_folder" 2>/dev/null | cut -f1 || echo "?")
        
        echo "📊 Estrutura a ser enviada:"
        echo "   📄 Arquivos: $file_count"
        echo "   📁 Subpastas: $((subdir_count - 1))"
        echo "   💾 Tamanho total: $total_size"
        echo
        
        # Mostrar algumas subpastas como exemplo
        echo "📋 Algumas subpastas encontradas:"
        find "$local_folder" -type d | head -5 | tail -4 | while read -r dir; do
            echo "   📂 ${dir#$local_folder/}"
        done
        if [[ $((subdir_count - 1)) -gt 4 ]]; then
            echo "   ... e mais $((subdir_count - 5)) subpastas"
        fi
        echo
    fi
    
    if confirm "📁 EXECUTAR UPLOAD COMPLETO DA ESTRUTURA?"; then
        echo "🚀 Iniciando upload completo..."
        sync_log "📁 UPLOAD COMPLETO DA ESTRUTURA INICIADO"
        
        if sync_complete_folder_structure "$local_folder" "$destination"; then
            echo "✅ Upload completo realizado com sucesso!"
            echo "🎯 Toda a estrutura foi enviada preservando as pastas"
            
            # Atualizar cache
            echo "💾 Atualizando cache..."
            local current_cache=""
            find "$local_folder" -type f -exec bash -c '
                file="$1"
                timestamp=$(stat -c "%Y" "$file" 2>/dev/null || echo "0")
                size=$(stat -c "%s" "$file" 2>/dev/null || echo "0")
                hash=$(echo "$size-$timestamp" | md5sum | cut -d" " -f1)
                echo "$file|$timestamp|$size|$hash"
            ' _ {} \; > "$SYNC_CACHE_FILE"
            
            echo "✅ Cache atualizado!"
        else
            echo "❌ Upload completo falhou"
            echo "💡 Verifique o log de debug para detalhes"
        fi
    fi
    
    pause
}

# Forçar reenvio completo ignorando cache
force_complete_resync() {
    local config=$(get_sync_config)
    local local_folder=$(echo "$config" | cut -d'|' -f1)
    local destination=$(echo "$config" | cut -d'|' -f2)
    
    if [[ -z "$local_folder" || -z "$destination" ]]; then
        echo "❌ Sincronização não configurada"
        pause
        return
    fi
    
    clear_screen
    echo "💪 Forçar Reenvio Completo"
    echo "═════════════════════════"
    echo "📁 Pasta: $(basename "$local_folder")"
    echo "🎯 Destino: $destination"
    echo
    echo "⚠️ ATENÇÃO:"
    echo "• Todos os arquivos serão reenviados"
    echo "• Cache atual será limpo"
    echo "• Processo pode demorar"
    echo
    
    # Mostrar estatísticas
    if [[ -d "$local_folder" ]]; then
        local file_count=$(find "$local_folder" -type f 2>/dev/null | wc -l)
        local subdir_count=$(find "$local_folder" -type d 2>/dev/null | wc -l)
        echo "📊 Serão enviados:"
        echo "   📄 $file_count arquivos"
        echo "   📁 $((subdir_count - 1)) subpastas"
        echo
    fi
    
    if confirm "💪 FORÇAR REENVIO COMPLETO DE TUDO?"; then
        echo "🔄 Limpando cache..."
        rm -f "$SYNC_CACHE_FILE"
        
        echo "📝 Iniciando log detalhado..."
        sync_log "💪 FORÇAR REENVIO COMPLETO INICIADO"
        sync_log "📁 Pasta: $local_folder"
        sync_log "🎯 Destino: $destination"
        
        echo "🚀 Executando reenvio forçado..."
        check_and_sync_changes "$local_folder" "$destination"
        
        echo "✅ Reenvio forçado concluído!"
        echo "💡 Verifique o log de debug para detalhes"
    fi
    
    pause
}

# Mostrar mudanças recentes detectadas
show_recent_changes() {
    clear_screen
    echo "🔍 Mudanças Recentes Detectadas"
    echo "═══════════════════════════════"
    
    if [[ ! -f "$SYNC_LOG_FILE" ]]; then
        echo "📝 Nenhum log encontrado"
        pause
        return
    fi
    
    echo "📊 Análise das últimas 50 entradas do log..."
    echo
    
    # Extrair mudanças do log
    local changes=$(tail -50 "$SYNC_LOG_FILE" | grep -E "(🆕|✏️|🔄|🗑️)")
    
    if [[ -z "$changes" ]]; then
        echo "😴 Nenhuma mudança detectada recentemente"
    else
        echo "📋 Mudanças encontradas:"
        echo "────────────────────────"
        echo "$changes" | while IFS= read -r line; do
            if [[ "$line" == *"🆕"* ]]; then
                echo "  $line"
            elif [[ "$line" == *"✏️"* ]]; then
                echo "  $line"
            elif [[ "$line" == *"🔄"* ]]; then
                echo "  $line"
            elif [[ "$line" == *"🗑️"* ]]; then
                echo "  $line"
            fi
        done
        
        echo
        echo "💡 Use 'Forçar Reenvio Completo' se os arquivos não estão sendo enviados"
    fi
    
    pause
}

# Sincronização manual
manual_sync() {
    local config=$(get_sync_config)
    local local_folder=$(echo "$config" | cut -d'|' -f1)
    local destination=$(echo "$config" | cut -d'|' -f2)
    
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
    echo
    
    if confirm "Executar sincronização manual agora?"; then
        echo "🔄 Verificando mudanças..."
        check_and_sync_changes "$local_folder" "$destination"
        echo "✅ Sincronização manual concluída!"
    fi
    
    pause
}

#===========================================
# MENU PRINCIPAL
#===========================================
# Menu principal
main_menu() {
    while true; do
        clear_screen
        
        # Verificar se há histórico
        local history_count=0
        if [[ -f "$HISTORY_FILE" ]]; then
            history_count=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
        fi
        
        # Criar opções do menu
        local menu_options=(
            "browser|📁 Navegador de Arquivos"
            "sync|🔄 Sincronização de Pasta"
            "quick|⚡ Upload Rápido (último item)"
            "history|📝 Histórico ($history_count itens)"
            "token|🔄 Renovar Token"
            "clean|🧹 Limpar Dados"
            "exit|❌ Sair"
        )
        
        # Mostrar menu
        local choice=$(printf '%s\n' "${menu_options[@]}" | \
            sed 's/^[^|]*|//' | \
            fzf --prompt="UPCODE > " \
                --header="Sistema de Upload de Arquivos" \
                --preview-window=hidden)
        
        # Encontrar a ação correspondente
        for option in "${menu_options[@]}"; do
            if [[ "$option" == *"|$choice" ]]; then
                local action=$(echo "$option" | cut -d'|' -f1)
                case "$action" in
                    "browser") file_browser ;;
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

# Limpar dados do sistema
clean_data() {
    clear_screen
    echo "🧹 Limpar Dados do Sistema"
    echo "─────────────────────────"
    echo
    
    local clean_options=(
        "token|🔑 Limpar Token (forçar novo login)"
        "history|📝 Limpar Histórico de Uploads"
        "sync|🔄 Limpar Configuração de Sincronização"
        "debug|🔍 Limpar Log de Debug"
        "all|🗑️ Limpar TUDO"
        "back|🔙 Voltar"
    )
    
    local choice=$(printf '%s\n' "${clean_options[@]}" | \
        sed 's/^[^|]*|//' | \
        fzf --prompt="Limpar > " \
            --header="O que deseja limpar?" \
            --height=10)
    
    # Encontrar a ação correspondente
    for option in "${clean_options[@]}"; do
        if [[ "$option" == *"|$choice" ]]; then
            local action=$(echo "$option" | cut -d'|' -f1)
            
            case "$action" in
                "token")
                    if confirm "Limpar token? (será necessário fazer login novamente)"; then
                        rm -f "$TOKEN_FILE"
                        echo "✅ Token removido!"
                        sleep 1
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
                    if confirm "Limpar configuração de sincronização? (irá parar sincronização ativa)"; then
                        stop_sync
                        rm -f "$SYNC_CONFIG_FILE" "$SYNC_CACHE_FILE"
                        echo "✅ Configuração de sincronização limpa!"
                        sleep 1
                    fi
                    ;;
                "debug")
                    if confirm "Limpar log de debug da sincronização?"; then
                        rm -f "$SYNC_LOG_FILE"
                        echo "✅ Log de debug limpo!"
                        sleep 1
                    fi
                    ;;
                "all")
                    if confirm "⚠️ LIMPAR TODOS OS DADOS? (token, histórico, sincronização e debug)"; then
                        stop_sync
                        rm -f "$TOKEN_FILE" "$HISTORY_FILE" "$SYNC_CONFIG_FILE" "$SYNC_CACHE_FILE" "$SYNC_LOG_FILE"
                        echo "✅ Todos os dados foram limpos!"
                        echo "ℹ️ Será necessário fazer login e reconfigurar sincronização"
                        sleep 2
                    fi
                    ;;
                "back")
                    return
                    ;;
            esac
            break
        fi
    done
}

#===========================================
# FUNÇÃO PRINCIPAL
#===========================================


show_banner
check_dependencies

if ! check_token; then
    do_login
fi

main_menu
