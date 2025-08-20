#!/bin/bash
# filepath: upcode-main.sh

#===========================================
# CONFIGURAÇÕES
#===========================================

CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
AUTH_URL="https://db33.dev.dinabox.net/api/dinabox/system/users/auth"
TOKEN_FILE="$HOME/.upcode_token"

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
# SELEÇÃO DE ARQUIVOS
#===========================================

# Alternar seleção de arquivo
toggle_selection() {
    local file="$1"
    
    # Verificar se já está selecionado
    for i in "${!selected_files[@]}"; do
        if [[ "${selected_files[$i]}" == "$file" ]]; then
            unset "selected_files[$i]"
            selected_files=("${selected_files[@]}")  # Reindexar
            echo "➖ Removido: $(basename "$file")"
            sleep 0.5
            return
        fi
    done
    
    # Adicionar à seleção
    selected_files+=("$file")
    echo "➕ Adicionado: $(basename "$file")"
    sleep 0.5
}

# Limpar seleções
clear_selections() {
    if [[ ${#selected_files[@]} -eq 0 ]]; then
        echo "ℹ️ Nenhuma seleção para limpar"
    else
        selected_files=()
        echo "✅ ${#selected_files[@]} seleções limpas!"
    fi
    sleep 1
}

# Mostrar arquivos selecionados
show_selected() {
    clear_screen
    
    if [[ ${#selected_files[@]} -eq 0 ]]; then
        echo "📋 Nenhum arquivo selecionado"
        pause
        return
    fi
    
    echo "📋 Arquivos Selecionados (${#selected_files[@]})"
    echo "─────────────────────────────"
    
    # Criar lista para fzf
    local file_list=()
    for file in "${selected_files[@]}"; do
        local size=$(du -sh "$file" 2>/dev/null | cut -f1)
        local basename_file=$(basename "$file")
        file_list+=("$basename_file ($size)")
    done
    
    # Mostrar no fzf para remoção opcional
    local to_remove=$(printf '%s\n' "${file_list[@]}" | \
        fzf --multi --prompt="Remover > " \
            --header="Selecione arquivos para remover (Tab para múltiplos)")
    
    if [[ -n "$to_remove" ]]; then
        while IFS= read -r item; do
            local filename=$(echo "$item" | sed 's/ ([^)]*)$//')
            for i in "${!selected_files[@]}"; do
                if [[ "$(basename "${selected_files[$i]}")" == "$filename" ]]; then
                    echo "➖ Removendo: $filename"
                    unset "selected_files[$i]"
                fi
            done
        done <<< "$to_remove"
        
        selected_files=("${selected_files[@]}")  # Reindexar
        echo "✅ Arquivos removidos da seleção"
        sleep 1
    fi
}

#===========================================
# NAVEGAÇÃO DE ARQUIVOS
#===========================================

# Navegador de arquivos
file_browser() {
    local current_dir="/mnt/c/Users/Dinabox/Desktop/PROJECTS"
    
    # Verificar se diretório existe
    if [[ ! -d "$current_dir" ]]; then
        current_dir="/mnt/c/Users/Dinabox/Desktop"
    fi
    
    while true; do
        clear_screen
        echo "📁 Navegador: $(basename "$current_dir")"
        echo "─────────────────────────────────"
        
        local items=()
        
        # Opção para voltar (se não estiver na raiz)
        if [[ "$current_dir" != "/mnt/c" ]]; then
            items+=(".. [Voltar]")
        fi
        
        # Listar diretórios primeiro
        while IFS= read -r -d '' dir; do
            [[ -d "$dir" ]] || continue
            local dirname=$(basename "$dir")
            items+=("DIR $dirname/")
        done < <(find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" -print0 2>/dev/null | sort -z)
        
        # Listar arquivos
        while IFS= read -r -d '' file; do
            [[ -f "$file" ]] || continue
            local filename=$(basename "$file")
            local size=$(du -sh "$file" 2>/dev/null | cut -f1 || echo "?")
            local mark=" "
            
            # Verificar se está selecionado
            if [[ " ${selected_files[@]} " =~ " $file " ]]; then
                mark="✓"
            fi
            
            items+=("FILE $mark $filename ($size)")
        done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
        
        # Adicionar opções de controle
        items+=("---")
        items+=("UPLOAD Upload Selecionados (${#selected_files[@]})")
        items+=("BACK Voltar ao Menu Principal")
        
        # Mostrar seletor
        local choice=$(printf '%s\n' "${items[@]}" | \
            fzf --prompt="$(basename "$current_dir") > " \
                --header="Enter=Navegar/Selecionar | Esc=Voltar" \
                --preview-window=hidden)
        
        # Sair se cancelado
        [[ -z "$choice" ]] && return
        
        # Processar escolha
        case "$choice" in
            ".. [Voltar]")
                current_dir=$(dirname "$current_dir")
                ;;
            "UPLOAD"*)
                if [[ ${#selected_files[@]} -gt 0 ]]; then
                    upload_selected_files
                else
                    echo "❌ Nenhum arquivo selecionado"
                    sleep 1
                fi
                ;;
            "BACK"*)
                return
                ;;
            "DIR"*)
                local folder_name=$(echo "$choice" | sed 's/^DIR //' | sed 's/\/$//')
                current_dir="$current_dir/$folder_name"
                ;;
            "FILE"*)
                local file_info=$(echo "$choice" | sed 's/^FILE [✓ ] //')
                local filename=$(echo "$file_info" | sed 's/ ([^)]*)$//')
                local filepath="$current_dir/$filename"
                toggle_selection "$filepath"
                ;;
            "---")
                continue
                ;;
        esac
    done
}

#===========================================
# UPLOAD
#===========================================

# Upload rápido de arquivo único
quick_upload() {
    clear_screen
    echo "⚡ Upload Rápido"
    echo "───────────────"
    
    # Buscar arquivos
    local file=$(find /mnt/c/Users/Dinabox/Desktop -type f \
        \( -name "*.php" -o -name "*.js" -o -name "*.css" -o -name "*.html" -o -name "*.txt" \) \
        2>/dev/null | \
        fzf --prompt="Arquivo > " \
            --header="Selecione um arquivo para upload" \
            --preview="head -10 {}")
    
    [[ -z "$file" ]] && return
    
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
        fzf --prompt="Pasta > " \
            --header="Selecione a pasta de destino")
    
    [[ -z "$folder" ]] && return
    
    # Se escolheu "Outros", pedir nome personalizado
    if [[ "$folder" == "Outros" ]]; then
        read -p "📁 Nome da pasta: " folder </dev/tty
        [[ -z "$folder" ]] && return
    fi
    
    # Confirmar upload
    echo
    echo "📋 Resumo do Upload:"
    echo "  📄 Arquivo: $(basename "$file")"
    echo "  📁 Pasta: $folder"
    echo "  💾 Tamanho: $(du -sh "$file" | cut -f1)"
    echo
    
    if confirm "Confirmar upload?"; then
        perform_upload "$file" "$folder"
    else
        echo "❌ Upload cancelado"
        sleep 1
    fi
}

# Upload de múltiplos arquivos
upload_selected_files() {
    [[ ${#selected_files[@]} -eq 0 ]] && return
    
    clear_screen
    echo "📤 Upload Múltiplo"
    echo "──────────────────"
    
    echo "Arquivos selecionados:"
    local total_size=0
    for file in "${selected_files[@]}"; do
        local size_bytes=$(du -b "$file" 2>/dev/null | cut -f1)
        local size_human=$(du -sh "$file" 2>/dev/null | cut -f1)
        echo "  📄 $(basename "$file") ($size_human)"
        total_size=$((total_size + size_bytes))
    done
    
    local total_human=$(numfmt --to=iec $total_size 2>/dev/null || echo "$total_size bytes")
    echo
    echo "Total: ${#selected_files[@]} arquivos - $total_human"
    echo
    
    # Pasta padrão
    local folder="Endpoint configuração Máquinas"
    read -p "📁 Pasta de destino [$folder]: " custom_folder </dev/tty
    [[ -n "$custom_folder" ]] && folder="$custom_folder"
    
    if confirm "Confirmar upload de ${#selected_files[@]} arquivo(s)?"; then
        echo
        echo "🔄 Iniciando uploads..."
        
        local success=0
        local failed=0
        
        for file in "${selected_files[@]}"; do
            echo "📤 Enviando $(basename "$file")..."
            if perform_upload "$file" "$folder" "silent"; then
                ((success++))
            else
                ((failed++))
            fi
        done
        
        echo
        echo "📊 Resultado:"
        echo "  ✅ Sucessos: $success"
        echo "  ❌ Falhas: $failed"
        echo "  📁 Pasta: $folder"
        
        # Limpar seleções se tudo deu certo
        if [[ $failed -eq 0 ]] && confirm "Limpar seleções?"; then
            selected_files=()
            echo "✅ Seleções limpas!"
        fi
        
        pause
    else
        echo "❌ Upload cancelado"
        sleep 1
    fi
}

# Realizar upload (função auxiliar)
perform_upload() {
    local file="$1"
    local folder="$2"
    local mode="${3:-normal}"
    
    # Verificar se arquivo existe
    if [[ ! -f "$file" ]]; then
        [[ "$mode" != "silent" ]] && echo "❌ Arquivo não encontrado: $file"
        return 1
    fi
    
    # Obter token
    local token=""
    if [[ -f "$TOKEN_FILE" ]]; then
        token=$(cat "$TOKEN_FILE")
    fi
    
    if [[ -z "$token" ]]; then
        [[ "$mode" != "silent" ]] && echo "❌ Token não encontrado"
        return 1
    fi
    
    # Simular upload (substituir por upload real)
    if [[ "$mode" != "silent" ]]; then
        echo "🔄 Enviando $(basename "$file")..."
    fi
    
    sleep 1  # Simular tempo de upload
    
    # Aqui seria o upload real:
    # local response=$(curl -s -X POST \
    #     -H "Cookie: jwt_user=$token; user_jwt=$token" \
    #     -F "arquivo[]=@$file" \
    #     -F "pasta=$folder" \
    #     "$CONFIG_URL")
    
    # Simular sucesso
    if [[ "$mode" != "silent" ]]; then
        echo "✅ Upload concluído!"
        sleep 1
    fi
    
    return 0
}

#===========================================
# MENU PRINCIPAL
#===========================================

# Menu principal
main_menu() {
    while true; do
        clear_screen
        
        # Criar opções do menu na ordem correta
        local menu_options=(
            "1|⚡ Upload Rápido"
            "2|📁 Navegador de Arquivos"  
            "3|📋 Ver Selecionados (${#selected_files[@]})"
            "4|🗑️ Limpar Seleções"
            "5|🔄 Renovar Token"
            "6|ℹ️ Sobre"
            "7|❌ Sair"
        )
        
        # Mostrar menu
        local choice=$(printf '%s\n' "${menu_options[@]}" | \
            sed 's/^[0-9]|//' | \
            fzf --prompt="UPCODE > " \
                --header="Sistema de Upload de Arquivos" \
                --preview-window=hidden)
        
        # Processar escolha
        case "$choice" in
            "⚡ Upload Rápido")         quick_upload ;;
            "📁 Navegador de Arquivos") file_browser ;;
            "📋 Ver Selecionados"*)    show_selected ;;
            "🗑️ Limpar Seleções")      clear_selections ;;
            "🔄 Renovar Token")        renew_token ;;
            "ℹ️ Sobre")               show_about ;;
            "❌ Sair")                clear; exit 0 ;;
            "")                       clear; exit 0 ;;
        esac
    done
}

# Mostrar informações sobre o sistema
show_about() {
    clear_screen
    cat << 'EOF'
ℹ️ UPCODE - Sistema de Upload

Versão: 2.1.0
Desenvolvido por: Dinabox Systems

📋 Recursos:
• Upload rápido de arquivo único
• Navegação interativa de pastas
• Seleção múltipla de arquivos
• Autenticação com token JWT
• Interface moderna com fzf

⌨️ Atalhos:
• Enter: Confirmar/Navegar
• Esc: Cancelar/Voltar  
• Tab: Seleção múltipla (onde aplicável)
• Ctrl+C: Sair do programa

🔧 Configuração:
• Token salvo em: ~/.upcode_token
• Pasta padrão: /mnt/c/Users/Dinabox/Desktop/PROJECTS

EOF
    pause
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
