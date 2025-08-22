#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-fixed.sh
# UPCODE - Sistema de Upload FUNCIONAL
# Versão corrigida com upload real de estrutura de pastas

#===========================================
# CONFIGURAÇÕES
#===========================================

CURRENT_VERSION="1.0.0"  # Adicionado
VERSION_URL="https://db33.dev.dinabox.net/upcode-version.php"  # Adicionado
UPDATE_URL="https://db33.dev.dinabox.net/upcode-fixed.sh"      # Adicionado
VERSION_FILE="$HOME/.upcode_version"                            # Adicionado

CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
AUTH_URL="https://db33.dev.dinabox.net/api/dinabox/system/users/auth"
TOKEN_FILE="$HOME/.upcode_token"
HISTORY_FILE="$HOME/.upcode_history"
SYNC_CONFIG_FILE="$HOME/.upcode_sync_config"
SYNC_CACHE_FILE="$HOME/.upcode_sync_cache"
SYNC_PID_FILE="$HOME/.upcode_sync_pid"
SYNC_LOG_FILE="$HOME/.upcode_sync_debug.log"

# Configurações de interface
FZF_DEFAULT_OPTS="--height=40% --border --margin=1 --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9"

#===========================================
# SISTEMA DE INSTALAÇÃO E ATUALIZAÇÃO (NOVO)
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
    
}



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

check_for_updates() {
    echo "🔄 Verificando atualizações..."
    
    # Verificar conexão
    if ! curl -s --max-time 5 "$VERSION_URL" > /dev/null 2>&1; then
        echo "⚠️  Sem conexão - pulando verificação"
        return 1
    fi
    
    local remote_version=$(curl -s --max-time 10 "$VERSION_URL" 2>/dev/null | grep -o '"version":"[^"]*' | cut -d'"' -f4)
    
    if [[ -n "$remote_version" && "$remote_version" != "$CURRENT_VERSION" ]]; then
        echo "🆕 Nova versão disponível: $remote_version"
        read -p "🚀 Deseja atualizar agora? (s/N): " -n 1 update_choice
        echo
        
        if [[ "$update_choice" =~ ^[sS]$ ]]; then
            echo "📥 Baixando atualização..."
            
            # Backup
            cp "$0" "$0.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Download
            local temp_file=$(mktemp)
            if curl -s --max-time 30 "$UPDATE_URL" -o "$temp_file" && [[ -s "$temp_file" ]]; then
                if head -1 "$temp_file" | grep -q "#!/bin/bash"; then
                    cp "$temp_file" "$0" && chmod +x "$0"
                    rm -f "$temp_file"
                    echo "✅ Atualização concluída! Reiniciando..."
                    sleep 1
                    exec "$0" "$@"
                fi
            fi
            
            echo "❌ Falha na atualização"
            rm -f "$temp_file"
        fi
    else
        echo "✅ Versão atual ($CURRENT_VERSION)"
    fi
    
    echo "$CURRENT_VERSION" > "$VERSION_FILE"
}

startup_check() {
    # Verificar uma vez por dia
    local today=$(date +%Y%m%d)
    local last_check=$(cat "$HOME/.upcode_last_check" 2>/dev/null || echo "0")
    
    if [[ "$today" != "$last_check" ]] || [[ "$1" == "--update" ]]; then
        check_for_updates "$@"
        echo "$today" > "$HOME/.upcode_last_check"
    fi
}

#===========================================
# UTILITÁRIOS (modificado apenas check_dependencies)
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
# AUTENTICAÇÃO
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
    clear_screen
    echo "🔐 Login necessário"
    echo "─────────────────"
    
    read -p "👤 Usuário [db17]: " username </dev/tty
    username=${username:-db17}
    read -s -p "🔑 Senha: " password </dev/tty
    echo
    
    if [[ -z "$username" || -z "$password" ]]; then
        echo "❌ Usuário e senha são obrigatórios!"
        pause
        exit 1
    fi
    
    echo "🔄 Autenticando..."
    
    local response=$(curl -s -X POST \
        -d "username=$username" \
        -d "password=$password" \
        "$AUTH_URL")
    
    local token=$(echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    if [[ -n "$token" && "$token" != "null" ]]; then
        echo "$token" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        echo "✅ Login realizado com sucesso!"
        sleep 1
        return 0
    else
        echo "❌ Falha na autenticação!"
        pause
        exit 1
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
        items+=("UPLOAD_CURRENT||📤 ENVIAR ESTA PASTA: $(basename "$current_dir")")
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
        echo
        
        local choice=$(printf '%s\n' "${items[@]}" | \
            sed 's/^[^|]*|[^|]*|//' | \
            fzf --prompt="📁 $(basename "$current_dir") > " \
                --header="Enter = Navegar/Selecionar | Esc = Voltar")
        
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
            "..")
                current_dir=$(dirname "$current_dir")
                ;;
            "DIR")
                current_dir="$path"
                ;;
            "FILE")
                upload_single_file "$path"
                ;;
            "UPLOAD_CURRENT")
                upload_folder_complete "$current_dir"
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
# UPLOAD DE ARQUIVOS E PASTAS - CORRIGIDO
#===========================================

upload_single_file() {
    local file="$1"
    
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
    
    echo
    echo "📋 Resumo:"
    echo "  📄 Arquivo: $(basename "$file")"
    echo "  📁 Destino: $folder"
    
    if confirm "Confirmar upload?"; then
        if perform_upload "$file" "$folder"; then
            add_to_history "$file" "file" "$folder"
        fi
    fi
}

upload_folder_complete() {
    local folder="$1"
    
    if [[ ! -d "$folder" ]]; then
        echo "❌ Pasta não encontrada: $folder"
        pause
        return 1
    fi
    
    clear_screen
    echo "📁 Upload Completo de Pasta"
    echo "═══════════════════════════"
    echo "📂 Pasta: $(basename "$folder")"
    echo "📍 Caminho: $folder"
    echo
    
    echo "🔄 Analisando estrutura..."
    local total_files=$(find "$folder" -type f 2>/dev/null | wc -l)
    local total_dirs=$(find "$folder" -type d 2>/dev/null | wc -l)
    local total_size=$(du -sh "$folder" 2>/dev/null | cut -f1 || echo "?")
    
    echo "📊 Estrutura encontrada:"
    echo "   📄 Arquivos: $total_files"
    echo "   📁 Subpastas: $((total_dirs - 1))"
    echo "   💾 Tamanho total: $total_size"
    echo
    
    if [[ $total_files -eq 0 ]]; then
        echo "⚠️ Nenhum arquivo encontrado na pasta"
        pause
        return 1
    fi
    
    # Mostrar algumas subpastas como exemplo
    if [[ $total_dirs -gt 1 ]]; then
        echo "📋 Algumas subpastas encontradas:"
        find "$folder" -type d | head -6 | tail -5 | while read -r dir; do
            local rel_path="${dir#$folder/}"
            echo "   📂 $rel_path"
        done
        if [[ $total_dirs -gt 6 ]]; then
            echo "   ... e mais $((total_dirs - 6)) subpastas"
        fi
        echo
    fi
    
    local folders=(
        "Cutprefers (endpoint)"
        "Resources (projetos avulso)"
        "Configurador de máquinas (out)"
        "teste fernando"
    )
    
    local destination=$(printf '%s\n' "${folders[@]}" | \
        fzf --prompt="🎯 Destino > " \
            --header="⚠️ TODA a estrutura será enviada!" \
            --height=10)
    
    [[ -z "$destination" ]] && return
    
    echo
    echo "📋 CONFIRMAÇÃO FINAL:"
    echo "═══════════════════════"
    echo "📂 Pasta origem: $(basename "$folder")"
    echo "🎯 Destino: $destination"
    echo "📊 Total: $total_files arquivos em $((total_dirs - 1)) subpastas"
    echo "💾 Tamanho: $total_size"
    echo
    echo "⚠️  ATENÇÃO: Toda a estrutura de pastas será recreada no servidor!"
    echo
    
    if confirm "🚀 CONFIRMAR UPLOAD COMPLETO DA ESTRUTURA?"; then
        if perform_complete_folder_upload "$folder" "$destination"; then
            add_to_history "$folder" "folder" "$destination"
        fi
    fi
}

perform_upload() {
    local file="$1"
    local folder="$2"
    
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
    echo "🔄 Enviando $filename..."
    
    local response=$(curl -s -X POST \
        -H "Cookie: jwt_user=$token; user_jwt=$token" \
        -F "arquivo[]=@$corrected_file" \
        -F "pasta=$folder" \
        "$CONFIG_URL" 2>&1)
    
    local curl_exit=$?
    
    if [[ $curl_exit -eq 0 ]] && echo "$response" | grep -q "enviados com sucesso"; then
        echo "✅ $filename - Upload realizado com sucesso!"
        return 0
    else
        echo "❌ $filename - Falha no upload"
        if [[ $curl_exit -ne 0 ]]; then
            echo "   Erro curl: $curl_exit"
        fi
    fi
    
    pause
    return 1
}

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

check_and_sync_changes() {
    local local_folder="$1"
    local destination="$2"
    
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
            files_to_sync+=("$file_path")
            sync_log "🆕 Novo: $(basename "$file_path")"
        else
            local old_timestamp=$(echo "$old_entry" | cut -d'|' -f2)
            if [[ "$timestamp" != "$old_timestamp" ]]; then
                files_to_sync+=("$file_path")
                sync_log "✏️ Modificado: $(basename "$file_path")"
            fi
        fi
    done <<< "$current_cache"
    
    # Se há mudanças, fazer upload completo da estrutura
    if [[ ${#files_to_sync[@]} -gt 0 ]]; then
        sync_log "🔄 ${#files_to_sync[@]} mudanças detectadas - fazendo upload completo"
        
        if perform_complete_folder_upload "$local_folder" "$destination" > /dev/null 2>&1; then
            sync_log "✅ Upload completo realizado"
            echo "$current_cache" > "$SYNC_CACHE_FILE"
        else
            sync_log "❌ Upload completo falhou"
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
    fi
    
    # Selecionar destino
    local folders=(
        "Cutprefers (endpoint)"
        "Resources (projetos avulso)"
        "Configurador de máquinas (out)"
        "teste fernando"
    )
    
    local destination=$(printf '%s\n' "${folders[@]}" | \
        fzf --prompt="Destino > " \
            --header="Selecione onde sincronizar" \
            --height=10)
    
    if [[ -z "$destination" ]]; then
        echo "❌ Configuração cancelada"
        sleep 2
        return
    fi
    
    # Selecionar intervalo
    local intervals=(
        "30|🔄 30 segundos (recomendado)"
        "60|⏰ 1 minuto"
        "300|🐌 5 minutos"
    )
    
    local interval_choice=$(printf '%s\n' "${intervals[@]}" | \
        sed 's/^[^|]*|//' | \
        fzf --prompt="Intervalo > " \
            --header="Frequência de verificação" \
            --height=8)
    
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
    
    # Salvar configuração
    echo "$selected_folder|$destination|$interval" > "$SYNC_CONFIG_FILE"
    
    # Criar cache inicial
    find "$selected_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort > "$SYNC_CACHE_FILE"
    
    clear_screen
    echo "✅ Sincronização Configurada!"
    echo "═══════════════════════════"
    echo "📁 Pasta: $(basename "$selected_folder")"
    echo "🎯 Destino: $destination"
    echo "⏱️ Intervalo: $interval segundos"
    echo
    
    if confirm "🚀 Iniciar sincronização agora?"; then
        # Iniciar daemon
        nohup bash -c "$(declare -f sync_daemon check_and_sync_changes perform_complete_folder_upload sync_log); sync_daemon '$selected_folder' '$destination' '$interval'" > /dev/null 2>&1 &
        local daemon_pid=$!
        
        echo "$daemon_pid" > "$SYNC_PID_FILE"
        echo "✅ Sincronização iniciada!"
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
        else
            sync_options+=("config|⚙️ Configurar Sincronização")
        fi
        
        sync_options+=("back|🔙 Voltar ao Menu Principal")
        
        local choice=$(printf '%s\n' "${sync_options[@]}" | \
            sed 's/^[^|]*|//' | \
            fzf --prompt="Sincronização > " \
                --header="Sincronização automática de pastas" \
                --height=12)
        
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
                    "back")
                        return
                        ;;
                esac
                break
            fi
        done
    done
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
    
    # Iniciar daemon
    nohup bash -c "$(declare -f sync_daemon check_and_sync_changes perform_complete_folder_upload sync_log); sync_daemon '$local_folder' '$destination' '$interval'" > /dev/null 2>&1 &
    local daemon_pid=$!
    
    echo "$daemon_pid" > "$SYNC_PID_FILE"
    
    echo "✅ Sincronização iniciada!"
    echo "📁 Pasta: $(basename "$local_folder")"
    echo "🎯 Destino: $destination"
    pause
}

show_sync_status() {
    clear_screen
    echo "📊 Status da Sincronização"
    echo "═════════════════════════"
    
    if ! is_sync_running; then
        echo "🔴 Sincronização não está ativa"
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
    
    if [[ -f "$SYNC_LOG_FILE" ]]; then
        echo "📋 Últimas atividades:"
        echo "─────────────────────"
        tail -10 "$SYNC_LOG_FILE" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
    
    pause
}

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
    
    if confirm "Executar sincronização manual?"; then
        echo "🔄 Executando upload completo..."
        if perform_complete_folder_upload "$local_folder" "$destination"; then
            echo "✅ Sincronização manual concluída!"
            # Atualizar cache
            find "$local_folder" -type f -exec stat -c '%n|%Y|%s' {} \; 2>/dev/null | sort > "$SYNC_CACHE_FILE"
        fi
    fi
    
    pause
}

#===========================================
# MENU PRINCIPAL
#===========================================

main_menu() {
    while true; do
        clear_screen
                
        local history_count=0
        if [[ -f "$HISTORY_FILE" ]]; then
            history_count=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
        fi
        
        local menu_options=(
            "browser|📁 Navegador de Arquivos"
            "sync|🔄 Sincronização de Pasta"
            "history|📝 Histórico ($history_count itens)"
            "update|🆙 Verificar Atualizações"        # NOVO
            "clean|🧹 Limpar Dados"
            "exit|❌ Sair"
        )
        
        local choice=$(printf '%s\n' "${menu_options[@]}" | \
            sed 's/^[^|]*|//' | \
            fzf --prompt="UPCODE > " \
                --header="Sistema de Upload de Arquivos v$CURRENT_VERSION" \
                --preview-window=hidden)
        
        for option in "${menu_options[@]}"; do
            if [[ "$option" == *"|$choice" ]]; then
                local action=$(echo "$option" | cut -d'|' -f1)
                case "$action" in
                    "browser") file_browser ;;
                    "sync") sync_menu ;;
                    "history") show_upload_history ;;
                    "update") check_for_updates; pause ;;    # NOVO
                    "clean") clean_data ;;
                    "exit") clear; exit 0 ;;
                esac
                break
            fi
        done
        
        [[ -z "$choice" ]] && { clear; exit 0; }
    done
}

clean_data() {
    clear_screen
    echo "🧹 Limpar Dados"
    echo "─────────────"
    echo
    
    local clean_options=(
        "token|🔑 Limpar Token"
        "history|📝 Limpar Histórico"
        "sync|🔄 Limpar Sincronização"
        "version|🗂️ Limpar Cache de Versão"          # NOVO
        "all|🗑️ Limpar TUDO"
        "back|🔙 Voltar"
    )
    
    local choice=$(printf '%s\n' "${clean_options[@]}" | \
        sed 's/^[^|]*|//' | \
        fzf --prompt="Limpar > " \
            --height=10)
    
    for option in "${clean_options[@]}"; do
        if [[ "$option" == *"|$choice" ]]; then
            local action=$(echo "$option" | cut -d'|' -f1)
            
            case "$action" in
                "token")
                    if confirm "Limpar token?"; then
                        rm -f "$TOKEN_FILE"
                        echo "✅ Token removido!"
                        sleep 1
                    fi
                    ;;
                "history")
                    if confirm "Limpar histórico?"; then
                        rm -f "$HISTORY_FILE"
                        echo "✅ Histórico limpo!"
                        sleep 1
                    fi
                    ;;
                "sync")
                    if confirm "Limpar sincronização?"; then
                        stop_sync
                        rm -f "$SYNC_CONFIG_FILE" "$SYNC_CACHE_FILE" "$SYNC_LOG_FILE"
                        echo "✅ Sincronização limpa!"
                        sleep 1
                    fi
                    ;;
                "version")                              # NOVO
                    if confirm "Limpar cache de versão?"; then
                        rm -f "$VERSION_FILE" "$HOME/.upcode_last_check"
                        echo "✅ Cache de versão limpo!"
                        sleep 1
                    fi
                    ;;
                "all")
                    if confirm "⚠️ LIMPAR TUDO?"; then
                        stop_sync
                        rm -f "$TOKEN_FILE" "$HISTORY_FILE" "$SYNC_CONFIG_FILE" "$SYNC_CACHE_FILE" "$SYNC_LOG_FILE" "$VERSION_FILE" "$HOME/.upcode_last_check"
                        echo "✅ Todos os dados limpos!"
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
# FUNÇÃO PRINCIPAL (modificada apenas para adicionar verificação)
#===========================================

main() {
    # Mostrar banner de inicialização
    show_banner
    echo "🔄 Iniciando sistema..."
    sleep 2
    
    # Verificar atualizações na inicialização
    startup_check "$@"
    
    check_dependencies
    
    if ! check_token; then
        do_login
    fi
    
    main_menu
}
# Executar com suporte a parâmetro --update
main "$@"
