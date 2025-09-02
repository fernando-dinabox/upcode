#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\main_01_01\main_01_09\upcode\upcode.sh

# Base URL do repositório
BASE_URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode"

# Função para carregar script remoto
load_remote_script() {
    local script_path="$1"
    local script_content=$(curl -s "$BASE_URL/$script_path")
    
    if [[ -n "$script_content" ]]; then
        eval "$script_content"
        return 0
    else
        echo "❌ Erro ao carregar: $script_path"
        return 1
    fi
}

echo "📦 Carregando scripts remotamente..."

# Carregar style
echo "  🎨 Carregando estilo FZF..."
load_remote_script "src/fzf_style.sh"
set_fzf_style

# Carregar os scripts da pasta src
echo "  🔐 Carregando autenticação..."
load_remote_script "src/auth.sh"

echo "  🛠️  Carregando utilitários..."
load_remote_script "src/utils.sh"

echo "  📦 Carregando dependências..."
load_remote_script "src/dependencies.sh"

echo "  📋 Carregando menus..."
load_remote_script "src/menus.sh"

echo "  🧭 Carregando navegação..."
load_remote_script "src/navigation.sh"

echo "  📤 Carregando uploads..."
load_remote_script "src/uploads.sh"

echo "  🔄 Carregando sincronização..."
load_remote_script "src/sync.sh"

echo "✅ Todos os scripts carregados!"
echo

CURRENT_VERSION="1.0.2"
CONFIG_URL="https://db33.dev.dinabox.net/upcode/upcode.php" 
AUTH_URL="https://db33.dev.dinabox.net/upcode/upcode.php"  
TOKEN_FILE="$HOME/.upcode_token"
HISTORY_FILE="$HOME/.upcode_history"
USER_FOLDERS_FILE="$HOME/.upcode_user_folders" 
USER_INFO_FILE="$HOME/.upcode_user_info" 
USER_CAN_DELETE=""
SYNC_LOG_FILE="$HOME/.upcode_sync.log"
SYNC_CACHE_FILE="$HOME/.upcode_sync.cache"

# Array para arquivos selecionados
declare -a selected_files=()
declare -a user_folders=()

# Variáveis para dados do usuário logado
USER_DISPLAY_NAME=""
USER_NICENAME=""
USER_EMAIL=""
USER_TYPE=""

# Chamar verificação no início
force_update_check
show_banner
check_dependencies

# Verificar token APENAS UMA VEZ no início
if ! check_token; then
    echo "🔍 Token não encontrado ou inválido - fazendo login..."
    do_login
else
    echo "✅ Token válido encontrado"
    load_user_folders
    echo "📁 Pastas carregadas: ${#user_folders[@]}"
fi

main_menu

# Voltar ao diretório original
cd "$ORIGINAL_DIR"
