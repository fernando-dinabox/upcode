#!/bin/bash
# filepath: upcode-main.sh

# Configurações
CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
TOKEN_FILE="$HOME/.upcode_token"

# Verificar se fzf está instalado
check_fzf() {
    if ! command -v fzf &> /dev/null; then
        echo "❌ fzf não encontrado. Instalando..."
        # Para WSL/Ubuntu: sudo apt install fzf
        # Para Windows: choco install fzf ou scoop install fzf
        echo "Execute: sudo apt install fzf"
        exit 1
    fi
}

# Menu principal com fzf
main_menu() {
    while true; do
        choice=$(echo -e "⚡ Upload Rápido\n📁 Navegador de Arquivos\n📋 Ver Seleções (${#selected_files[@]})\n🗑️ Limpar Seleções\nℹ️ Sobre\n❌ Sair" | \
        fzf --height=40% --border --prompt="🚀 UPCODE > " --header="Sistema de Upload")
        
        case "$choice" in
            "⚡ Upload Rápido") quick_upload ;;
            "📁 Navegador de Arquivos") file_browser ;;
            "📋 Ver Seleções"*) show_selected ;;
            "🗑️ Limpar Seleções") selected_files=(); echo "✅ Limpo!" ;;
            "ℹ️ Sobre") show_about ;;
            "❌ Sair") exit 0 ;;
            *) [[ -z "$choice" ]] && exit 0 ;;
        esac
    done
}

# Navegador de arquivos com fzf
file_browser() {
    local current_dir="${1:-/mnt/c/Users/Dinabox/Desktop/PROJECTS}"
    
    while true; do
        # Preparar lista de itens
        local items=$(find "$current_dir" -maxdepth 1 \( -type f -o -type d \) ! -path "$current_dir" | \
            while read item; do
                if [[ -d "$item" ]]; then
                    echo "📁 $(basename "$item")/"
                else
                    local size=$(du -h "$item" | cut -f1)
                    local mark=""
                    [[ " ${selected_files[@]} " =~ " $item " ]] && mark="✓ "
                    echo "📄 ${mark}$(basename "$item") ($size)"
                fi
            done | sort)
        
        # Adicionar opções especiais
        if [[ "$current_dir" != "/mnt/c" ]]; then
            items="🔙 ..
$items"
        fi
        items="$items
📤 Upload Selecionados
🔙 Voltar ao Menu"
        
        # Mostrar seletor
        choice=$(echo "$items" | fzf --height=80% --border --multi \
            --prompt="📁 $(basename "$current_dir") > " \
            --header="Tab=Selecionar múltiplos | Enter=Navegar/Ação")
        
        [[ -z "$choice" ]] && return
        
        case "$choice" in
            "🔙 ..")
                current_dir=$(dirname "$current_dir")
                ;;
            "🔙 Voltar ao Menu")
                return
                ;;
            "📤 Upload Selecionados")
                upload_selected_files
                ;;
            📁*)
                local folder=$(echo "$choice" | sed 's/📁 //' | sed 's/\/$//')
                current_dir="$current_dir/$folder"
                ;;
            📄*)
                local filename=$(echo "$choice" | sed 's/📄 //' | sed 's/✓ //' | cut -d' ' -f1)
                local filepath="$current_dir/$filename"
                toggle_selection "$filepath"
                ;;
        esac
    done
}

# Upload rápido com seleção de arquivo
quick_upload() {
    local file=$(find /mnt/c/Users/Dinabox/Desktop -type f -name "*.php" -o -name "*.js" -o -name "*.css" | \
        fzf --height=60% --border --prompt="📄 Selecionar arquivo > " --preview="head -20 {}")
    
    [[ -z "$file" ]] && return
    
    local folder=$(echo -e "Endpoint configuração Máquinas\nOutra pasta..." | \
        fzf --height=30% --border --prompt="📁 Pasta destino > ")
    
    [[ -z "$folder" ]] && return
    
    if [[ "$folder" == "Outra pasta..." ]]; then
        read -p "Digite o nome da pasta: " folder
    fi
    
    echo "📤 Enviando $(basename "$file") para $folder..."
    # Simular upload
    sleep 2
    echo "✅ Upload concluído!"
    read -p "Pressione Enter..."
}

declare -a selected_files=()

toggle_selection() {
    local file="$1"
    local found=0
    
    for i in "${!selected_files[@]}"; do
        if [[ "${selected_files[$i]}" == "$file" ]]; then
            unset "selected_files[$i]"
            selected_files=("${selected_files[@]}")
            echo "➖ Removido: $(basename "$file")"
            found=1
            break
        fi
    done
    
    if [[ $found -eq 0 ]]; then
        selected_files+=("$file")
        echo "➕ Adicionado: $(basename "$file")"
    fi
    
    sleep 1
}

show_selected() {
    if [[ ${#selected_files[@]} -eq 0 ]]; then
        echo "Nenhum arquivo selecionado"
        read -p "Pressione Enter..."
        return
    fi
    
    local selection=$(printf '%s\n' "${selected_files[@]}" | \
        fzf --height=60% --border --prompt="📋 Selecionados > " --multi \
        --header="Enter=Remover | Tab=Múltipla seleção")
    
    # Remover arquivos selecionados
    for item in $selection; do
        toggle_selection "$item"
    done
}

upload_selected_files() {
    [[ ${#selected_files[@]} -eq 0 ]] && echo "Nenhum arquivo selecionado" && sleep 2 && return
    
    echo "📤 Uploading ${#selected_files[@]} arquivos..."
    for file in "${selected_files[@]}"; do
        echo "  📄 $(basename "$file")"
    done
    
    read -p "Confirmar upload? (s/N): " confirm
    [[ "$confirm" =~ ^[sS]$ ]] || return
    
    echo "🔄 Enviando arquivos..."
    sleep 3
    echo "✅ Todos os arquivos enviados!"
    selected_files=()
    read -p "Pressione Enter..."
}

show_about() {
    echo "🚀 UPCODE v2.0 - Sistema de Upload
    
📋 Recursos:
• Interface moderna com fzf
• Navegação intuitiva
• Seleção múltipla
• Preview de arquivos

⚡ Atalhos:
• Tab: Seleção múltipla
• Ctrl+C: Sair
• Enter: Confirmar

Desenvolvido por Dinabox Systems"
    read -p "Pressione Enter..."
}

# Função principal
main() {
    check_fzf
    main_menu
}

main
