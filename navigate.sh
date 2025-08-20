#!/bin/bash
# Navegador de Diretórios Simples

# Configurações de interface
FZF_DEFAULT_OPTS="--height=40% --border --margin=1 --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9"

# Verificar dependências
check_dependencies() {
    if ! command -v fzf &> /dev/null; then
        echo "❌ Erro: fzf não encontrado"
        echo "📦 Execute: sudo apt install fzf"
        exit 1
    fi
}

# Limpar tela
clear_screen() {
    clear
    echo "📁 NAVEGADOR DE DIRETÓRIOS"
    echo "═════════════════════════"
    echo
}

# Navegador de diretórios
directory_browser() {
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
        echo "📂 Caminho atual: $current_dir"
        echo "─────────────────────────────────"
        
        local items=()
        
        # Opção para voltar (se não estiver na raiz)
        if [[ "$current_dir" != "/" && "$current_dir" != "/mnt/c" ]]; then
            items+=(".. [🔙 Voltar]")
        fi
        
        local dir_count=0
        
        # Listar apenas diretórios
        if [[ -r "$current_dir" ]]; then
            while IFS= read -r item; do
                [[ -z "$item" ]] && continue
                local full_path="$current_dir/$item"
                if [[ -d "$full_path" ]]; then
                    items+=("DIR|$full_path|📂 $item/")
                    ((dir_count++))
                fi
            done < <(ls -1 "$current_dir" 2>/dev/null | head -100)
        else
            items+=("❌ Sem permissão para ler este diretório")
        fi
        
        # Adicionar opções de controle
        items+=("")
        items+=("--- [🛠️ OPÇÕES] ---")
        items+=("SELECT||✅ Selecionar este diretório")
        items+=("EXIT||❌ Sair")
        
        # Mostrar contador
        echo "📊 Encontradas: $dir_count pastas"
        echo
        
        # Mostrar seletor
        local choice=$(printf '%s\n' "${items[@]}" | \
            sed 's/^[^|]*|[^|]*|//' | \
            fzf --prompt="$(basename "$current_dir") > " \
                --header="Enter=Navegar | Tab=Selecionar diretório atual" \
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
            "SELECT")
                echo "✅ Diretório selecionado: $current_dir"
                
                # Converter para caminho Windows se necessário
                local windows_path="$current_dir"
                if [[ "$current_dir" =~ ^/mnt/c/ ]]; then
                    windows_path=$(echo "$current_dir" | sed 's|^/mnt/c|C:|' | sed 's|/|\\|g')
                fi
                
                echo "📁 Caminho Linux: $current_dir"
                echo "📁 Caminho Windows: $windows_path"
                echo
                
                # Ir para o diretório
                if cd "$current_dir" 2>/dev/null; then
                    echo "🎯 Navegado para: $current_dir"
                    export SELECTED_DIR="$current_dir"
                    
                    # Abrir bash no diretório
                    echo "🚀 Abrindo terminal no diretório..."
                    exec bash
                else
                    echo "❌ Não foi possível acessar o diretório"
                    read -p "Pressione Enter para continuar..."
                fi
                ;;
            "EXIT")
                echo "👋 Saindo..."
                exit 0
                ;;
            "")
                # Linhas vazias ou separadores - ignorar
                continue
                ;;
            *)
                # Processar seleções diretas
                if [[ "$choice" == *"[🔙 Voltar]" ]]; then
                    current_dir=$(dirname "$current_dir")
                elif [[ "$choice" == *"📂"* && "$choice" == *"/" ]]; then
                    # É um diretório
                    local folder_name=$(echo "$choice" | sed 's/📂 //' | sed 's/\/$//')
                    current_dir="$current_dir/$folder_name"
                elif [[ "$choice" == *"✅ Selecionar"* ]]; then
                    # Selecionou o diretório atual
                    echo "✅ Diretório selecionado: $current_dir"
                    cd "$current_dir" 2>/dev/null && exec bash
                fi
                ;;
        esac
    done
}

# Função principal
main() {
    # Verificar dependências
    check_dependencies
    
    # Iniciar navegador
    directory_browser "$@"
}

# Executar
main "$@"