#!/bin/bash
# filepath: upcode-main.sh

# Configurações
AUTH_URL="https://db33.dev.dinabox.net/api/dinabox/system/users/auth"
CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
TOKEN_FILE="$HOME/.upcode_token"

# Função para verificar se token existe e é válido
check_token() {
    if [[ -f "$TOKEN_FILE" ]]; then
        local token=$(cat "$TOKEN_FILE")
        # Verificar se o token não está vazio
        if [[ -n "$token" ]]; then
            echo "✅ Token encontrado"
            return 0
        fi
    fi
    return 1
}

# Função para fazer login e obter token
do_login() {
    echo "🔐 Sistema de Upload - Login necessário"
    echo "─────────────────────────────────────"
    
    # Redirecionar entrada para /dev/tty para funcionar com pipe
    read -p "👤 Usuário: " username </dev/tty
    read -s -p "🔑 Senha: " password </dev/tty
    echo
    
    # Validação
    if [[ -z "$username" || -z "$password" ]]; then
        echo "❌ Usuário e senha são obrigatórios!"
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
        chmod 600 "$TOKEN_FILE"  # Permissões seguras
        echo "✅ Login realizado com sucesso!"
        return 0
    else
        echo "❌ Falha na autenticação!"
        echo "Resposta da API: $response"
        exit 1
    fi
}

# Função para mostrar menu principal
show_menu() {
    clear
    echo "🚀 Sistema de Upload - Menu Principal"
    echo "═══════════════════════════════════════"
    echo
    echo "1. 📤 Upload de arquivo"
    echo "2. 📁 Selecionar pasta"
    echo "3. 🔄 Renovar token"
    echo "4. ❌ Sair"
    echo
    read -p "Escolha uma opção [1-4]: " choice </dev/tty
    
    case $choice in
        1) upload_file_menu ;;
        2) select_folder_menu ;;
        3) renew_token ;;
        4) exit 0 ;;
        *) 
            echo "❌ Opção inválida!"
            sleep 1
            show_menu
            ;;
    esac
}

# Função para renovar token
renew_token() {
    echo "🔄 Renovando token..."
    rm -f "$TOKEN_FILE"
    do_login
    show_menu
}

# Função para menu de upload
upload_file_menu() {
    echo
    echo "📤 Upload de Arquivo"
    echo "─────────────────────"
    
    # Arquivo padrão
    local default_file="/mnt/c/Users/Dinabox/Desktop/PROJECTS/Endpoints/db_cut_prefers.php"
    
    echo "Arquivo padrão: $default_file"
    read -p "Pressione Enter para usar o padrão ou digite outro caminho: " custom_file </dev/tty
    
    local file_path="${custom_file:-$default_file}"
    
    # Pasta padrão
    local default_folder="Endpoint configuração Máquinas"
    echo "Pasta padrão: $default_folder"
    read -p "Pressione Enter para usar o padrão ou digite outra pasta: " custom_folder </dev/tty
    
    local folder_name="${custom_folder:-$default_folder}"
    
    upload_file "$file_path" "$folder_name"
}

# Função para selecionar pasta (menu futuro)
select_folder_menu() {
    echo
    echo "📁 Seleção de Pasta"
    echo "─────────────────────"
    echo "🚧 Funcionalidade em desenvolvimento..."
    echo
    read -p "Pressione Enter para voltar ao menu..." </dev/tty
    show_menu
}

# Função de upload
upload_file() {
    local arquivo="$1"
    local pasta="$2"
    local token=$(cat "$TOKEN_FILE")
    
    # Verificar se arquivo existe
    if [[ ! -f "$arquivo" ]]; then
        echo "❌ Arquivo não encontrado: $arquivo"
        read -p "Pressione Enter para continuar..." </dev/tty
        show_menu
        return 1
    fi
    
    echo "📤 Enviando arquivo..."
    echo "📄 Arquivo: $(basename "$arquivo")"
    echo "📁 Pasta: $pasta"
    
    # Upload
    local response=$(curl -s -X POST \
        -H "Cookie: jwt_user=$token; user_jwt=$token" \
        -F "arquivo[]=@$arquivo" \
        -F "pasta=$pasta" \
        "$CONFIG_URL")
    
    # Status
    local filename=$(basename "$arquivo")
    if echo "$response" | grep -q "Arquivos enviados com sucesso"; then
        echo "✅ $filename - Enviado com sucesso"
    elif echo "$response" | grep -q "Usuário autenticado"; then
        echo "⚠️ $filename - Autenticado mas sem confirmação"
    else
        echo "❌ $filename - Erro no upload"
        echo "Resposta: $response"
    fi
    
    echo
    read -p "Pressione Enter para voltar ao menu..." </dev/tty
    show_menu
}

# Função principal
main() {
    # Verificar se já tem token válido
    if ! check_token; then
        do_login
    fi
    
    # Mostrar menu principal
    show_menu
}

# Executar
main
