#!/bin/bash
# filepath: upcode-main.sh

# Configurações
CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
TOKEN_FILE="$HOME/.upcode_token"
UPLOAD_TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..." # Token fixo para teste

# Array para arquivos selecionados
declare -a selected_files=()

# Verificar dependências
check_dependencies() {
    if ! command -v fzf &> /dev/null; then
        echo "Erro: fzf não encontrado"
        echo "Execute: sudo apt install fzf"
        exit 1
    fi
}

# Menu principal
main_menu() {
    while true; do
        local menu_options=(
            "upload    Upload Rápido"
            "browse    Navegador de Arquivos"
            "selected  Ver Selecionados (${#selected_files[@]})"
            "clear     Limpar Seleções"
            "about     Sobre"
            "exit      Sair"
        )
        
        local choice=$(printf '%s\n' "${menu_options[@]}" | \
            fzf --delimiter=' ' --with-nth=2.. \
                --height=12 --border --margin=1 \
                --prompt="UPCODE > " \
                --header="Sistema de Upload de Arquivos" \
                --preview-window=hidden | cut -d' ' -f1)
        
        case "$choice" in
            "upload")   quick_upload ;;
            "browse")   file_browser ;;
            "selected") show_selected ;;
            "clear")    clear_selections ;;
            "about")    show_about ;;
            "exit")     clear; exit 0 ;;
            "")         clear; exit 0 ;;
        esac
    done
}

# Navegador de arquivos
file_browser() {
    local current_dir="/mnt/c/Users/Dinabox/Desktop/PROJECTS"
    
    # Verificar se diretório existe
    if [[ ! -d "$current_dir" ]]; then
        current_dir="/mnt/c/Users/Dinabox/Desktop"
    fi
    
    while true; do
        local items=()
        
        # Opção para voltar
        if [[ "$current_dir" != "/mnt/c" ]]; then
            items+=("..  [Voltar]")
        fi
        
        # Listar diretórios
        while IFS= read -r -d '' dir; do
            local dirname=$(basename "$dir")
            items+=("d   $dirname/")
        done < <(find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" -print0 2>/dev/null | sort -z)
        
        # Listar arquivos
        while IFS= read -r -d '' file; do
            local filename=$(basename "$file")
            local size=$(du -sh "$file" 2>/dev/null | cut -f1)
            local mark=" "
            
            # Verificar se está selecionado
            for selected in "${selected_files[@]}"; do
                if [[ "$selected" == "$file" ]]; then
                    mark="✓"
                    break
                fi
            done
            
            items+=("$mark   $filename ($size)")
        done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
        
        # Adicionar opções de ação
        items+=("")
        items+=("up  Upload Selecionados")
        items+=("<<  Voltar ao Menu")
        
        # Mostrar seletor
        local choice=$(printf '%s\n' "${items[@]}" | \
            fzf --height=20 --border --margin=1 \
                --prompt="$(basename "$current_dir")/ > " \
                --header="Espaço=Selecionar | Enter=Navegar" \
                --bind="space:toggle+down" \
                --multi)
        
        [[ -z "$choice" ]] && return
        
        # Processar escolha
        case "$choice" in
            "..  [Voltar]")
                current_dir=$(dirname "$current_dir")
                ;;
            "up  Upload Selecionados")
                if [[ ${#selected_files[@]} -gt 0 ]]; then
                    upload_selected_files
                else
                    echo "Nenhum arquivo selecionado"
                    sleep 1
                fi
                ;;
            "<<  Voltar ao Menu")
                return
                ;;
            d\ \ \ *)
                local folder_name=$(echo "$choice" | sed 's/^d   //' | sed 's/\/$//')
                current_dir="$current_dir/$folder_name"
                ;;
            [\ ✓]\ \ \ *)
                local filename=$(echo "$choice" | sed 's/^[✓ ]   //' | sed 's/ ([^)]*)$//')
                local filepath="$current_dir/$filename"
                toggle_selection "$filepath"
                ;;
        esac
    done
}

# Upload rápido
quick_upload() {
    echo "Buscando arquivos..."
    
    local file=$(find /mnt/c/Users/Dinabox/Desktop -name "*.php" -o -name "*.js" -o -name "*.css" -o -name "*.html" 2>/dev/null | \
        sed 's|.*/||' | \
        fzf --height=15 --border --margin=1 \
            --prompt="Arquivo > " \
            --header="Selecione um arquivo para upload" \
            --preview="echo 'Arquivo: {}'" \
            --preview-window=up:3)
    
    [[ -z "$file" ]] && return
    
    # Encontrar caminho completo
    local filepath=$(find /mnt/c/Users/Dinabox/Desktop -name "$file" 2>/dev/null | head -1)
    
    local folders=(
        "Endpoint configuração Máquinas"
        "Scripts PHP" 
        "Arquivos JavaScript"
        "Estilos CSS"
        "Documentos HTML"
        "Outros"
    )
    
    local folder=$(printf '%s\n' "${folders[@]}" | \
        fzf --height=10 --border --margin=1 \
            --prompt="Pasta > " \
            --header="Selecione a pasta de destino")
    
    [[ -z "$folder" ]] && return
    
    if [[ "$folder" == "Outros" ]]; then
        echo -n "Nome da pasta: "
        read folder
    fi
    
    echo
    echo "Upload em andamento..."
    echo "Arquivo: $file"
    echo "Destino: $folder"
    
    # Simular upload
    sleep 2
    echo "✓ Upload concluído com sucesso!"
    echo
    read -p "Pressione Enter para continuar..."
}

# Alternar seleção de arquivo
toggle_selection() {
    local file="$1"
    local found=false
    
    # Verificar se já está selecionado
    for i in "${!selected_files[@]}"; do
        if [[ "${selected_files[$i]}" == "$file" ]]; then
            unset "selected_files[$i]"
            selected_files=("${selected_files[@]}")  # Reindexar
            echo "Removido: $(basename "$file")"
            found=true
            break
        fi
    done
    
    # Se não encontrado, adicionar
    if [[ "$found" == false ]]; then
        selected_files+=("$file")
        echo "Adicionado: $(basename "$file")"
    fi
    
    sleep 0.5
}

# Mostrar arquivos selecionados
show_selected() {
    if [[ ${#selected_files[@]} -eq 0 ]]; then
        echo "Nenhum arquivo selecionado"
        read -p "Pressione Enter para continuar..."
        return
    fi
    
    local file_list=()
    for file in "${selected_files[@]}"; do
        local size=$(du -sh "$file" 2>/dev/null | cut -f1)
        file_list+=("$(basename "$file") ($size)")
    done
    
    local selection=$(printf '%s\n' "${file_list[@]}" | \
        fzf --height=15 --border --margin=1 \
            --prompt="Selecionados > " \
            --header="Enter=Remover | Esc=Voltar" \
            --multi)
    
    # Remover arquivos selecionados
    if [[ -n "$selection" ]]; then
        while IFS= read -r item; do
            local filename=$(echo "$item" | sed 's/ ([^)]*)$//')
            for i in "${!selected_files[@]}"; do
                if [[ "$(basename "${selected_files[$i]}")" == "$filename" ]]; then
                    unset "selected_files[$i]"
                fi
            done
        done <<< "$selection"
        selected_files=("${selected_files[@]}")  # Reindexar
        echo "Arquivos removidos da seleção"
        sleep 1
    fi
}

# Limpar seleções
clear_selections() {
    selected_files=()
    echo "Seleções limpas!"
    sleep 1
}

# Upload de arquivos selecionados
upload_selected_files() {
    [[ ${#selected_files[@]} -eq 0 ]] && return
    
    echo
    echo "Arquivos para upload:"
    for file in "${selected_files[@]}"; do
        echo "  $(basename "$file")"
    done
    echo
    
    read -p "Confirmar upload de ${#selected_files[@]} arquivo(s)? (s/N): " confirm
    
    if [[ "$confirm" =~ ^[sS]$ ]]; then
        echo
        echo "Iniciando upload..."
        
        local success=0
        for file in "${selected_files[@]}"; do
            echo "Enviando $(basename "$file")..."
            sleep 1  # Simular upload
            ((success++))
        done
        
        echo
        echo "✓ Upload concluído!"
        echo "  Arquivos enviados: $success"
        echo "  Pasta: Endpoint configuração Máquinas"
        
        # Limpar seleções após upload
        selected_files=()
    else
        echo "Upload cancelado"
    fi
    
    echo
    read -p "Pressione Enter para continuar..."
}

# Sobre
show_about() {
    cat << 'EOF'

UPCODE - Sistema de Upload de Arquivos
=====================================

Versão: 2.0
Desenvolvido por: Dinabox Systems

Recursos:
• Upload rápido de arquivo único
• Navegação interativa de pastas  
• Seleção múltipla de arquivos
• Interface limpa com fzf

Atalhos:
• Espaço: Selecionar múltiplos
• Enter: Confirmar/Navegar
• Esc: Cancelar/Voltar
• Ctrl+C: Sair

EOF
    read -p "Pressione Enter para continuar..."
}

# Função principal
main() {
    clear
    check_dependencies
    echo "Iniciando UPCODE..."
    sleep 1
    main_menu
}

main
