#!/bin/bash
# filepath: upcode-main.sh

#===========================================
# CONFIGURAÇÕES
#===========================================

CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
AUTH_URL="https://db33.dev.dinabox.net/api/dinabox/system/users/auth"
TOKEN_FILE="$HOME/.upcode_token"
HISTORY_FILE="$HOME/.upcode_history"
BOOKMARKS_FILE="$HOME/.upcode_bookmarks"

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
    
    read -p "👤 Usuário: " username </dev/tty
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
    local file="$1"
    
    # Criar arquivo de histórico se não existir
    touch "$HISTORY_FILE"
    
    # Remover entrada anterior se existir
    grep -v "^$file$" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null || true
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE" 2>/dev/null || true
    
    # Adicionar no topo
    echo "$file" >> "$HISTORY_FILE"
    
    # Manter apenas os últimos 20
    tail -n 20 "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# Adicionar pasta aos favoritos
add_bookmark() {
    local dir="$1"
    local name="$2"
    
    touch "$BOOKMARKS_FILE"
    
    # Verificar se já existe
    if ! grep -q "^$dir|" "$BOOKMARKS_FILE" 2>/dev/null; then
        echo "$dir|$name" >> "$BOOKMARKS_FILE"
        echo "✅ Pasta adicionada aos favoritos: $name"
    else
        echo "ℹ️ Pasta já está nos favoritos"
    fi
    sleep 1
}

# Listar favoritos
list_bookmarks() {
    if [[ ! -f "$BOOKMARKS_FILE" ]] || [[ ! -s "$BOOKMARKS_FILE" ]]; then
        return 1
    fi
    
    local bookmarks=()
    while IFS='|' read -r path name; do
        [[ -d "$path" ]] && bookmarks+=("📁 $name|$path")
    done < "$BOOKMARKS_FILE"
    
    if [[ ${#bookmarks[@]} -eq 0 ]]; then
        return 1
    fi
    
    printf '%s\n' "${bookmarks[@]}"
    return 0
}

#===========================================
# NAVEGAÇÃO DE ARQUIVOS - VERSÃO CORRIGIDA
#===========================================

# Navegador de arquivos melhorado e mais rápido
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
        
        # Adicionar favoritos se existirem
        if list_bookmarks > /dev/null 2>&1; then
            items+=("")
            items+=("--- [⭐ FAVORITOS] ---")
            while IFS= read -r bookmark; do
                local bookmark_name=$(echo "$bookmark" | cut -d'|' -f1 | sed 's/📁 //')
                local bookmark_path=$(echo "$bookmark" | cut -d'|' -f2)
                items+=("BOOKMARK|$bookmark_path|⭐ $bookmark_name")
            done < <(list_bookmarks)
            items+=("")
            items+=("--- [📂 CONTEÚDO ATUAL] ---")
        fi
        
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
        items+=("ADD_BOOKMARK||⭐ Adicionar aos favoritos")
        items+=("HISTORY||📝 Ver histórico ($([[ -f "$HISTORY_FILE" ]] && wc -l < "$HISTORY_FILE" || echo 0) arquivos)")
        items+=("BACK||🔙 Voltar ao menu principal")
        
        # Mostrar contador
        echo "📊 Encontrados: $dir_count pastas, $file_count arquivos"
        echo
        
        # Mostrar seletor
        local choice=$(printf '%s\n' "${items[@]}" | \
            sed 's/^[^|]*|[^|]*|//' | \
            fzf --prompt="$(basename "$current_dir") > " \
                --header="Enter=Navegar/Selecionar | Esc=Voltar | /=Buscar" \
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
            "BOOKMARK")
                current_dir="$path"
                ;;
            "DIR")
                current_dir="$path"
                ;;
            "FILE")
                show_file_options "$path"
                ;;
            "ADD_BOOKMARK")
                echo
                read -p "📝 Nome para este favorito [$(basename "$current_dir")]: " bookmark_name </dev/tty
                [[ -z "$bookmark_name" ]] && bookmark_name=$(basename "$current_dir")
                add_bookmark "$current_dir" "$bookmark_name"
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

# Mostrar histórico de uploads
show_upload_history() {
    if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
        clear_screen
        echo "📝 Histórico de Uploads"
        echo "─────────────────────"
        echo "Nenhum arquivo foi enviado ainda"
        pause
        return
    fi
    
    local history_files=()
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local size=$(du -sh "$file" 2>/dev/null | cut -f1 || echo "?")
            local basename_file=$(basename "$file")
            history_files+=("FILE|$file|📄 $basename_file ($size)")
        fi
    done < <(tac "$HISTORY_FILE")  # Inverter ordem (mais recentes primeiro)
    
    if [[ ${#history_files[@]} -eq 0 ]]; then
        clear_screen
        echo "📝 Histórico de Uploads"
        echo "─────────────────────"
        echo "Nenhum arquivo disponível no histórico"
        pause
        return
    fi
    
    local choice=$(printf '%s\n' "${history_files[@]}" | \
        sed 's/^[^|]*|[^|]*|//' | \
        fzf --prompt="Histórico > " \
            --header="Selecione um arquivo do histórico")
    
    if [[ -n "$choice" ]]; then
        # Encontrar o arquivo correspondente
        for item in "${history_files[@]}"; do
            if [[ "$item" == *"|$choice" ]]; then
                local selected_file=$(echo "$item" | cut -d'|' -f2)
                upload_single_file "$selected_file"
                break
            fi
        done
    fi
}

#===========================================
# UPLOAD
#===========================================

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
        "Endpoint configuração Máquinas"
        "Scripts PHP"
        "Arquivos JavaScript"
        "Estilos CSS"
        "Documentos HTML"
        "Outros"
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
            add_to_history "$file"
        fi
    else
        echo "❌ Upload cancelado"
        sleep 1
    fi
}

# Upload rápido (do histórico)
quick_upload() {
    if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
        clear_screen
        echo "📝 Nenhum histórico encontrado"
        echo "Use o navegador de arquivos primeiro"
        pause
        return
    fi
    
    # Pegar o último arquivo do histórico
    local last_file=$(tail -n 1 "$HISTORY_FILE")
    
    if [[ -f "$last_file" ]]; then
        clear_screen
        echo "⚡ Upload Rápido"
        echo "──────────────"
        echo "Último arquivo enviado:"
        echo "📄 $(basename "$last_file")"
        echo "💾 $(du -sh "$last_file" 2>/dev/null | cut -f1 || echo "N/A")"
        echo
        
        if confirm "Enviar novamente este arquivo?"; then
            upload_single_file "$last_file"
        fi
    else
        echo "❌ Último arquivo não encontrado"
        pause
    fi
}

# Realizar upload (função auxiliar)
perform_upload() {
    local file="$1"
    local folder="$2"
    
    # Verificar se arquivo existe
    if [[ ! -f "$file" ]]; then
        echo "❌ Arquivo não encontrado: $file"
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
    
    echo "🔄 Enviando $(basename "$file")..."
    
    # Realizar upload real
    local response=$(curl -s -X POST \
        -H "Cookie: jwt_user=$token; user_jwt=$token" \
        -F "arquivo[]=@$file" \
        -F "pasta=$folder" \
        "$CONFIG_URL")
    
    # Verificar resultado
    if echo "$response" | grep -q "Arquivos enviados com sucesso"; then
        echo "✅ Upload concluído com sucesso!"
        sleep 1
        return 0
    elif echo "$response" | grep -q "Usuário autenticado"; then
        echo "⚠️ Upload realizado mas sem confirmação completa"
        sleep 1
        return 0
    else
        echo "❌ Erro no upload"
        echo "Resposta: $response"
        pause
        return 1
    fi
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
            "quick|⚡ Upload Rápido (último arquivo)"
            "history|📝 Histórico ($history_count arquivos)"
            "favorites|⭐ Gerenciar Favoritos"
            "token|🔄 Renovar Token"
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
                    "quick") quick_upload ;;
                    "history") show_upload_history ;;
                    "favorites") manage_bookmarks ;;
                    "token") renew_token ;;
                    "exit") clear; exit 0 ;;
                esac
                break
            fi
        done
        
        # Se não encontrou correspondência e choice está vazio, sair
        [[ -z "$choice" ]] && { clear; exit 0; }
    done
}

# Gerenciar favoritos
manage_bookmarks() {
    if [[ ! -f "$BOOKMARKS_FILE" ]] || [[ ! -s "$BOOKMARKS_FILE" ]]; then
        clear_screen
        echo "⭐ Gerenciar Favoritos"
        echo "────────────────────"
        echo "Nenhum favorito cadastrado"
        echo
        echo "Use o navegador de arquivos e adicione pastas aos favoritos"
        pause
        return
    fi
    
    local bookmarks=()
    while IFS='|' read -r path name; do
        if [[ -d "$path" ]]; then
            bookmarks+=("BOOKMARK|$path|📁 $name")
        fi
    done < "$BOOKMARKS_FILE"
    
    bookmarks+=("BACK||🔙 Voltar")
    
    local choice=$(printf '%s\n' "${bookmarks[@]}" | \
        sed 's/^[^|]*|[^|]*|//' | \
        fzf --prompt="Favoritos > " \
            --header="Selecione um favorito ou volte")
    
    if [[ "$choice" == "🔙 Voltar" ]]; then
        return
    elif [[ -n "$choice" ]]; then
        # Encontrar o caminho correspondente
        for item in "${bookmarks[@]}"; do
            if [[ "$item" == *"|$choice" ]]; then
                local selected_path=$(echo "$item" | cut -d'|' -f2)
                file_browser "$selected_path"
                break
            fi
        done
    fi
}

#===========================================
# FUNÇÃO PRINCIPAL
#===========================================

main() {
    # Verificar dependências
    check_dependencies
    
    # Verificar autenticação
    if ! check_token; then
        do_login
    fi
    
    # Iniciar menu principal
    main_menu
}

# Executar
main
