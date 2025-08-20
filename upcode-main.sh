#!/bin/bash
# filepath: upcode-main.sh

# Configurações
AUTH_URL="https://db33.dev.dinabox.net/api/dinabox/system/users/auth"
CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
TOKEN_FILE="$HOME/.upcode_token"

# Cores para interface
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Arrays para seleção múltipla
declare -a selected_files=()
declare -a selected_folders=()

#===========================================
# FUNÇÕES DE AUTENTICAÇÃO (COMENTADAS)
#===========================================

# # Função para verificar se token existe e é válido
# check_token() {
#     if [[ -f "$TOKEN_FILE" ]]; then
#         local token=$(cat "$TOKEN_FILE")
#         if [[ -n "$token" ]]; then
#             echo -e "${GREEN}✅ Token encontrado${NC}"
#             return 0
#         fi
#     fi
#     return 1
# }

# # Função para fazer login e obter token
# do_login() {
#     echo -e "${CYAN}🔐 Sistema de Upload - Login necessário${NC}"
#     echo "─────────────────────────────────────"
#     
#     read -p "👤 Usuário: " username </dev/tty
#     read -s -p "🔑 Senha: " password </dev/tty
#     echo
#     
#     if [[ -z "$username" || -z "$password" ]]; then
#         echo -e "${RED}❌ Usuário e senha são obrigatórios!${NC}"
#         exit 1
#     fi
#     
#     echo -e "${YELLOW}🔄 Autenticando...${NC}"
#     
#     local response=$(curl -s -X POST \
#         -d "username=$username" \
#         -d "password=$password" \
#         "$AUTH_URL")
#     
#     local token=$(echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
#     
#     if [[ -n "$token" && "$token" != "null" ]]; then
#         echo "$token" > "$TOKEN_FILE"
#         chmod 600 "$TOKEN_FILE"
#         echo -e "${GREEN}✅ Login realizado com sucesso!${NC}"
#         return 0
#     else
#         echo -e "${RED}❌ Falha na autenticação!${NC}"
#         echo "Resposta da API: $response"
#         exit 1
#     fi
# }

#===========================================
# FUNÇÕES DE INTERFACE
#===========================================

# Função para limpar tela e mostrar cabeçalho
show_header() {
    clear
    echo -e "${CYAN}🚀 Sistema de Upload - UPCODE${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
}

# Função para pausar e aguardar input
pause() {
    echo
    read -p "Pressione Enter para continuar..." </dev/tty
}

# Função para confirmar ação
confirm() {
    local message="$1"
    echo -e "${YELLOW}$message (s/N):${NC} "
    read -n 1 response </dev/tty
    echo
    [[ "$response" =~ ^[sS]$ ]]
}

#===========================================
# FUNÇÕES DE NAVEGAÇÃO DE ARQUIVOS
#===========================================

# Função para listar itens do diretório atual
list_directory() {
    local current_dir="$1"
    local -i index=1
    
    echo -e "${BLUE}📁 Pasta atual:${NC} $current_dir"
    echo "─────────────────────────────────────"
    
    # Opção para voltar (se não estiver na raiz)
    if [[ "$current_dir" != "/" && "$current_dir" != "/mnt/c" ]]; then
        echo -e "${YELLOW}0.${NC} 🔙 ${YELLOW}[Voltar]${NC}"
    fi
    
    # Listar diretórios primeiro
    while IFS= read -r -d '' dir; do
        local dir_name=$(basename "$dir")
        echo -e "${YELLOW}$index.${NC} 📁 ${BLUE}$dir_name/${NC}"
        ((index++))
    done < <(find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" -print0 2>/dev/null | sort -z)
    
    # Listar arquivos
    while IFS= read -r -d '' file; do
        local file_name=$(basename "$file")
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        local selected_mark=""
        
        # Verificar se arquivo está selecionado
        if [[ " ${selected_files[@]} " =~ " $file " ]]; then
            selected_mark="${GREEN}[✓]${NC} "
        fi
        
        echo -e "${YELLOW}$index.${NC} 📄 ${selected_mark}$file_name ${CYAN}($size)${NC}"
        ((index++))
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
    
    echo
    echo -e "${CYAN}Comandos:${NC}"
    echo "• [número] - Navegar/Selecionar"
    echo "• [s] - Mostrar selecionados"
    echo "• [c] - Limpar seleções"
    echo "• [u] - Fazer upload"
    echo "• [q] - Voltar ao menu principal"
}

# Função para navegação interativa de arquivos
file_navigator() {
    local current_dir="${1:-/mnt/c/Users/Dinabox/Desktop/PROJECTS}"
    
    # Verificar se diretório existe
    if [[ ! -d "$current_dir" ]]; then
        current_dir="/mnt/c/Users/Dinabox/Desktop"
    fi
    
    while true; do
        show_header
        list_directory "$current_dir"
        
        echo -e "${YELLOW}Digite sua escolha:${NC} "
        read -r choice </dev/tty
        
        case "$choice" in
            "0")
                # Voltar um diretório
                current_dir=$(dirname "$current_dir")
                ;;
            "s")
                show_selected_files
                ;;
            "c")
                clear_selections
                ;;
            "u")
                if [[ ${#selected_files[@]} -gt 0 ]]; then
                    upload_selected_files
                else
                    echo -e "${RED}❌ Nenhum arquivo selecionado!${NC}"
                    pause
                fi
                ;;
            "q")
                return
                ;;
            [0-9]*)
                navigate_to_item "$current_dir" "$choice"
                if [[ $? -eq 1 ]]; then
                    current_dir="$navigation_result"
                fi
                ;;
            *)
                echo -e "${RED}❌ Opção inválida!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Variável global para resultado da navegação
navigation_result=""

# Função para navegar para item específico
navigate_to_item() {
    local current_dir="$1"
    local choice="$2"
    local -i index=1
    local -i target_index="$choice"
    
    # Se não estiver na raiz, ajustar índice (0 é voltar)
    if [[ "$current_dir" != "/" && "$current_dir" != "/mnt/c" ]]; then
        if [[ $target_index -eq 0 ]]; then
            navigation_result=$(dirname "$current_dir")
            return 1
        fi
    fi
    
    # Processar diretórios primeiro
    while IFS= read -r -d '' dir; do
        if [[ $index -eq $target_index ]]; then
            navigation_result="$dir"
            return 1  # Indica mudança de diretório
        fi
        ((index++))
    done < <(find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" -print0 2>/dev/null | sort -z)
    
    # Processar arquivos
    while IFS= read -r -d '' file; do
        if [[ $index -eq $target_index ]]; then
            toggle_file_selection "$file"
            return 0  # Indica seleção de arquivo
        fi
        ((index++))
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
    
    echo -e "${RED}❌ Índice inválido!${NC}"
    sleep 1
    return 0
}

# Função para alternar seleção de arquivo
toggle_file_selection() {
    local file="$1"
    
    # Verificar se arquivo já está selecionado
    local found=0
    for i in "${!selected_files[@]}"; do
        if [[ "${selected_files[$i]}" == "$file" ]]; then
            # Remover da seleção
            unset "selected_files[$i]"
            selected_files=("${selected_files[@]}")  # Reindexar array
            echo -e "${YELLOW}➖ Arquivo removido da seleção:${NC} $(basename "$file")"
            found=1
            break
        fi
    done
    
    if [[ $found -eq 0 ]]; then
        # Adicionar à seleção
        selected_files+=("$file")
        echo -e "${GREEN}➕ Arquivo adicionado à seleção:${NC} $(basename "$file")"
    fi
    
    sleep 1
}

# Função para mostrar arquivos selecionados
show_selected_files() {
    show_header
    echo -e "${GREEN}📋 Arquivos Selecionados:${NC}"
    echo "─────────────────────────────────────"
    
    if [[ ${#selected_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Nenhum arquivo selecionado${NC}"
    else
        local total_size=0
        for i in "${!selected_files[@]}"; do
            local file="${selected_files[$i]}"
            local size=$(du -b "$file" 2>/dev/null | cut -f1)
            local size_human=$(du -h "$file" 2>/dev/null | cut -f1)
            echo -e "${YELLOW}$(($i + 1)).${NC} 📄 $(basename "$file") ${CYAN}($size_human)${NC}"
            echo "    ${BLUE}↳ $file${NC}"
            total_size=$((total_size + size))
        done
        echo
        local total_human=$(numfmt --to=iec $total_size 2>/dev/null || echo "$total_size bytes")
        echo -e "${CYAN}Total: ${#selected_files[@]} arquivos - $total_human${NC}"
    fi
    
    pause
}

# Função para limpar seleções
clear_selections() {
    selected_files=()
    echo -e "${GREEN}✅ Seleções limpas!${NC}"
    sleep 1
}

#===========================================
# FUNÇÕES DE UPLOAD
#===========================================

# Função para upload dos arquivos selecionados
upload_selected_files() {
    show_header
    echo -e "${GREEN}🚀 Upload de Arquivos Selecionados${NC}"
    echo "─────────────────────────────────────"
    
    echo -e "${BLUE}Arquivos que serão enviados:${NC}"
    for file in "${selected_files[@]}"; do
        echo -e "  📄 $(basename "$file")"
    done
    echo
    
    # Solicitar pasta de destino
    local default_folder="Endpoint configuração Máquinas"
    echo -e "${YELLOW}Pasta de destino padrão:${NC} $default_folder"
    read -p "Pressione Enter para usar o padrão ou digite outra pasta: " custom_folder </dev/tty
    
    local folder_name="${custom_folder:-$default_folder}"
    
    if ! confirm "Confirmar upload para a pasta '$folder_name'?"; then
        echo -e "${YELLOW}Upload cancelado${NC}"
        pause
        return
    fi
    
    # Simular upload (sem token real)
    echo -e "${YELLOW}🔄 Iniciando uploads...${NC}"
    echo
    
    local success_count=0
    local total_files=${#selected_files[@]}
    
    for file in "${selected_files[@]}"; do
        local filename=$(basename "$file")
        echo -n "📤 Enviando $filename... "
        
        # Simular delay de upload
        sleep 1
        
        # Simular resultado (sem fazer upload real)
        if [[ -f "$file" ]]; then
            echo -e "${GREEN}✅ Sucesso${NC}"
            ((success_count++))
        else
            echo -e "${RED}❌ Arquivo não encontrado${NC}"
        fi
    done
    
    echo
    echo -e "${CYAN}📊 Resultado:${NC}"
    echo -e "  ✅ Sucessos: $success_count"
    echo -e "  ❌ Falhas: $((total_files - success_count))"
    echo -e "  📁 Pasta de destino: $folder_name"
    
    if confirm "Limpar seleções após upload?"; then
        clear_selections
    fi
    
    pause
}

# Função de upload rápido (arquivo único)
quick_upload() {
    show_header
    echo -e "${GREEN}⚡ Upload Rápido${NC}"
    echo "─────────────────────────────────────"
    
    local default_file="/mnt/c/Users/Dinabox/Desktop/PROJECTS/Endpoints/db_cut_prefers.php"
    
    echo -e "${YELLOW}Arquivo padrão:${NC} $default_file"
    read -p "Pressione Enter para usar o padrão ou digite outro caminho: " custom_file </dev/tty
    
    local file_path="${custom_file:-$default_file}"
    
    if [[ ! -f "$file_path" ]]; then
        echo -e "${RED}❌ Arquivo não encontrado: $file_path${NC}"
        pause
        return
    fi
    
    local default_folder="Endpoint configuração Máquinas"
    echo -e "${YELLOW}Pasta padrão:${NC} $default_folder"
    read -p "Pressione Enter para usar o padrão ou digite outra pasta: " custom_folder </dev/tty
    
    local folder_name="${custom_folder:-$default_folder}"
    
    echo -e "${BLUE}📋 Resumo do Upload:${NC}"
    echo -e "  📄 Arquivo: $(basename "$file_path")"
    echo -e "  📁 Pasta: $folder_name"
    echo -e "  💾 Tamanho: $(du -h "$file_path" | cut -f1)"
    echo
    
    if confirm "Confirmar upload?"; then
        echo -e "${YELLOW}🔄 Enviando arquivo...${NC}"
        sleep 2  # Simular upload
        echo -e "${GREEN}✅ Upload realizado com sucesso!${NC}"
    else
        echo -e "${YELLOW}Upload cancelado${NC}"
    fi
    
    pause
}

#===========================================
# MENU PRINCIPAL
#===========================================

# Função para mostrar menu principal
show_menu() {
    while true; do
        show_header
        echo -e "${YELLOW}Menu Principal:${NC}"
        echo "─────────────────────────────────────"
        echo -e "1. ⚡ ${GREEN}Upload Rápido${NC} (arquivo único)"
        echo -e "2. 📁 ${BLUE}Navegador de Arquivos${NC} (seleção múltipla)"
        echo -e "3. 📋 ${CYAN}Ver Seleções Atuais${NC} (${#selected_files[@]} arquivos)"
        echo -e "4. 🗑️  ${YELLOW}Limpar Seleções${NC}"
        echo -e "5. ℹ️  ${BLUE}Sobre o Sistema${NC}"
        echo -e "6. ❌ ${RED}Sair${NC}"
        echo
        
        read -p "Escolha uma opção [1-6]: " choice </dev/tty
        
        case $choice in
            1) quick_upload ;;
            2) file_navigator ;;
            3) show_selected_files ;;
            4) 
                clear_selections
                echo -e "${GREEN}✅ Seleções limpas!${NC}"
                sleep 1
                ;;
            5) show_about ;;
            6) 
                echo -e "${CYAN}👋 Até logo!${NC}"
                exit 0 
                ;;
            *) 
                echo -e "${RED}❌ Opção inválida!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Função sobre o sistema
show_about() {
    show_header
    echo -e "${CYAN}ℹ️  Sobre o Sistema UPCODE${NC}"
    echo "─────────────────────────────────────"
    echo -e "${YELLOW}Versão:${NC} 2.0.0"
    echo -e "${YELLOW}Desenvolvido por:${NC} Dinabox Systems"
    echo -e "${YELLOW}Recursos:${NC}"
    echo "  • Upload rápido de arquivo único"
    echo "  • Navegação interativa de pastas"
    echo "  • Seleção múltipla de arquivos"
    echo "  • Interface colorida e intuitiva"
    echo "  • Cache de token para autenticação"
    echo
    echo -e "${BLUE}Configurações atuais:${NC}"
    echo "  • URL da API: $AUTH_URL"
    echo "  • URL de Upload: $CONFIG_URL"
    echo "  • Arquivo de Token: $TOKEN_FILE"
    echo
    pause
}

#===========================================
# FUNÇÃO PRINCIPAL
#===========================================

main() {
    # Comentado: verificação de login
    # if ! check_token; then
    #     do_login
    # fi
    
    # Mostrar menu principal
    show_menu
}

# Executar
main
