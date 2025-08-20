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
# NAVEGAÇÃO DE ARQUIVOS
#===========================================

# Navegador de arquivos melhorado
file_browser() {
    local current_dir="${1:-$HOME}"
    
    # Se o diretório não existir, começar do HOME
    if [[ ! -d "$current_dir" ]]; then
        current_dir="$HOME"
    fi
    
    while true; do
        clear_screen
        echo "📁 Navegador: $(basename "$current_dir")"
        echo "Caminho: $current_dir"
        echo "─────────────────────────────────"
        
        local items=()
        
        # Opção para voltar (se não estiver na raiz)
        if [[ "$current_dir" != "/" ]]; then
            items+=(".. 🔙 Voltar")
        fi
        
        # Adicionar favoritos se existirem
        if list_bookmarks > /dev/null 2>&1; then
            items+=("--- ⭐ FAVORITOS ---")
            while IFS= read -r bookmark; do
                items+=("BOOKMARK $bookmark")
            done < <(list_bookmarks)
            items+=("--- 📂 PASTAS E ARQUIVOS ---")
        fi
        
        # Listar diretórios primeiro
        while IFS= read -r -d '' dir; do
            [[ -d "$dir" ]] || continue
            local dirname=$(basename "$dir")
            items+=("DIR 📂 $dirname/")
        done < <(find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" -print0 2>/dev/null | sort -z)
        
        # Listar arquivos
        while IFS= read -r -d '' file; do
            [[ -f "$file" ]] || continue
            local filename=$(basename "$file")
            local size=$(du -sh "$file" 2>/dev/null | cut -f1 || echo "?")
            
            # Verificar se está no histórico
            local history_mark=""
            if [[ -f "$HISTORY_FILE" ]] && grep -q "^$file$" "$HISTORY_FILE" 2>/dev/null; then
                history_mark="⭐ "
            fi
            
            items+=("FILE 📄 $history_mark$filename ($size)")
        done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
        
        # Adicionar opções de controle
        items+=("---")
        items+=("ADD_BOOKMARK ⭐ Adicionar pasta aos favoritos")
        items+=("HISTORY 📝 Ver histórico de uploads")
        items+=("BACK 🔙 Voltar ao menu principal")
        
        # Mostrar seletor
        local choice=$(printf '%s\n' "${items[@]}" | \
            fzf --prompt="$(basename "$current_dir") > " \
                --header="Enter=Navegar/Selecionar | Esc=Voltar" \
                --preview-window=hidden)
        
        # Sair se cancelado
        [[ -z "$choice" ]] && return
        
        # Processar escolha
        case "$choice" in
            ".. 🔙 Voltar")
                current_dir=$(dirname "$current_dir")
                ;;
            "ADD_BOOKMARK"*)
                read -p "📝 Nome para este favorito: " bookmark_name </dev/tty
                [[ -n "$bookmark_name" ]] && add_bookmark "$current_dir" "$bookmark_name"
                ;;
            "HISTORY"*)
                show_upload_history
                ;;
            "BACK"*)
                return
                ;;
            "BOOKMARK"*)
                local bookmark_path=$(echo "$choice" | cut -d'|' -f2)
                current_dir="$bookmark_path"
                ;;
            "DIR"*)
                local folder_name=$(echo "$choice" | sed 's/^DIR 📂 //' | sed 's/\/$//')
                current_dir="$current_dir/$folder_name"
                ;;
            "FILE"*)
                local file_info=$(echo "$choice" | sed 's/^FILE 📄 //' | sed 's/^⭐ //')
                local filename=$(echo "$file_info" | sed 's/ ([^)]*)$//')
                local filepath="$current_dir/$filename"
                
                # Mostrar opções para o arquivo
                show_file_options "$filepath"
                ;;
            "---"* | *"FAVORITOS"* | *"PASTAS E ARQUIVOS"*)
                continue
                ;;
        esac
    done
}

# Mostrar opções para arquivo selecionado
show_file_options() {
    local file="$1"
    
    local options=(
        "upload 📤 Upload deste arquivo"
        "info ℹ️ Informações do arquivo"
        "back 🔙 Voltar"
    )
    
    local choice=$(printf '%s\n' "${options[@]}" | \
        sed 's/^[^ ]* //' | \
        fzf --prompt="Arquivo: $(basename "$file") > " \
            --header="Escolha uma ação" \
            --height=10)
    
    case "$choice" in
        "📤 Upload deste arquivo")
            upload_single_file "$file"
            ;;
        "ℹ️ Informações do arquivo")
            show_file_info "$file"
            ;;
    esac
}

# Mostrar informações do arquivo
show_file_info() {
    local file="$1"
    
    clear_screen
    echo "ℹ️ Informações do Arquivo"
    echo "─────────────────────────"
    echo "📄 Nome: $(basename "$file")"
    echo "📁 Pasta: $(dirname "$file")"
    echo "💾 Tamanho: $(du -sh "$file" | cut -f1)"
    echo "📅 Modificado: $(stat -c '%y' "$file" 2>/dev/null | cut -d. -f1)"
    echo "🔗 Caminho completo: $file"
    
    # Verificar se está no histórico
    if [[ -f "$HISTORY_FILE" ]] && grep -q "^$file$" "$HISTORY_FILE" 2>/dev/null; then
        echo "⭐ Status: Já foi enviado anteriormente"
    else
        echo "📝 Status: Nunca foi enviado"
    fi
    
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
            local size=$(du -sh "$file" 2>/dev/null | cut -f1)
            history_files+=("📄 $(basename "$file") ($size)|$file")
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
        fzf --prompt="Histórico > " \
            --header="Selecione um arquivo do histórico" \
            --delimiter='|' --with-nth=1)
    
    if [[ -n "$choice" ]]; then
        local selected_file=$(echo "$choice" | cut -d'|' -f2)
        upload_single_file "$selected_file"
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
    echo "💾 Tamanho: $(du -sh "$file" | cut -f1)"
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
        read -p "📁 Nome da pasta: " folder </dev/tty
        [[ -z "$folder" ]] && return
    fi
    
    echo
    echo "📋 Resumo:"
    echo "  📄 Arquivo: $(basename "$file")"
    echo "  📁 Destino: $folder"
    echo "  💾 Tamanho: $(du -sh "$file" | cut -f1)"
    
    # Verificar se já foi enviado
    if [[ -f "$HISTORY_FILE" ]] && grep -q "^$file$" "$HISTORY_FILE" 2>/dev/null; then
        echo "  ⚠️ Este arquivo já foi enviado anteriormente"
    fi
    
    echo
    
    if confirm "Confirmar upload?"; then
        perform_upload "$file" "$folder"
        # Adicionar ao histórico após sucesso
        add_to_history "$file"
    else
        echo "❌ Upload cancelado"
        sleep 1
    fi
}

# Upload rápido (do histórico)
quick_upload() {
    if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
        echo "📝 Nenhum histórico encontrado"
        echo "Use o navegador de arquivos primeiro"
        pause
        return
    fi
    
    # Pegar o último arquivo do histórico
    local last_file=$(tail -n 1 "$HISTORY_FILE")
    
    if [[ -f "$last_file" ]]; then
        echo "⚡ Upload rápido do último arquivo:"
        echo "📄 $(basename "$last_file")"
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
            "1|📁 Navegador de Arquivos"
            "2|⚡ Upload Rápido (último arquivo)"
            "3|📝 Histórico ($history_count arquivos)"
            "4|⭐ Gerenciar Favoritos"
            "5|🔄 Renovar Token"
            "6|❌ Sair"
        )
        
        # Mostrar menu
        local choice=$(printf '%s\n' "${menu_options[@]}" | \
            sed 's/^[0-9]|//' | \
            fzf --prompt="UPCODE > " \
                --header="Sistema de Upload de Arquivos" \
                --preview-window=hidden)
        
        # Processar escolha
        case "$choice" in
            "📁 Navegador de Arquivos") file_browser ;;
            "⚡ Upload Rápido"*) quick_upload ;;
            "📝 Histórico"*) show_upload_history ;;
            "⭐ Gerenciar Favoritos") manage_bookmarks ;;
            "🔄 Renovar Token") renew_token ;;
            "❌ Sair") clear; exit 0 ;;
            "") clear; exit 0 ;;
        esac
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
            bookmarks+=("📁 $name|$path")
        fi
    done < "$BOOKMARKS_FILE"
    
    bookmarks+=("🔙 Voltar")
    
    local choice=$(printf '%s\n' "${bookmarks[@]}" | \
        fzf --prompt="Favoritos > " \
            --header="Selecione um favorito ou volte" \
            --delimiter='|' --with-nth=1)
    
    if [[ "$choice" == "🔙 Voltar" ]]; then
        return
    elif [[ -n "$choice" ]]; then
        local selected_path=$(echo "$choice" | cut -d'|' -f2)
        file_browser "$selected_path"
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
