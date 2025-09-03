#!/bin/bash

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

echo "📦 Iniciando loading de arquivos..."

load_remote_script "src/fzf_style.sh"
set_fzf_style

# Carregar os scripts da pasta src
load_remote_script "src/auth.sh"
load_remote_script "src/utils.sh"
load_remote_script "src/dependencies.sh"
load_remote_script "src/menus.sh"
load_remote_script "src/navigation.sh"
load_remote_script "src/uploads.sh"
load_remote_script "src/sync.sh"

echo "✅ Carregamento concluido!"
echo "Iniciando Upcode!"
echo

CURRENT_VERSION="1.1.6"
CONFIG_URL="https://db33.dev.dinabox.net/upcode/upcode.php" 
AUTH_URL="https://db33.dev.dinabox.net/upcode/upcode.php"  

# Criar diretório upcode
UPCODE_DIR="$HOME/.upcode"
mkdir -p "$UPCODE_DIR"

TOKEN_FILE="$UPCODE_DIR/token"
HISTORY_FILE="$UPCODE_DIR/history"
USER_CAN_DELETE=""
SYNC_LOG_FILE="$UPCODE_DIR/sync.log"
SYNC_CACHE_FILE="$UPCODE_DIR/sync.cache"

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
    # PRIMEIRO carregar pastas em memória
    load_user_folders
    # DEPOIS carregar dados do usuário silenciosamente
    load_user_info "silent" 2>/dev/null || true
    echo "📁 Pastas carregadas: ${#user_folders[@]}"
    if [[ -n "$USER_DISPLAY_NAME" ]]; then
        echo "👤 Usuário: $USER_DISPLAY_NAME"
    fi
fi

main_menu

# Voltar ao diretório original
cd "$ORIGINAL_DIR"
