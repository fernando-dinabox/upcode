#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\main_01_01\main_01_09\upcode\upcode.sh

# Base URL do repositório
BASE_URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode"


# Definir pasta para arquivos temporários do upcode
UPCODE_TEMP_DIR="$HOME/.upcode"

# Criar pasta se não existir
if [[ ! -d "$UPCODE_TEMP_DIR" ]]; then
    mkdir -p "$UPCODE_TEMP_DIR"
fi

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

CURRENT_VERSION="1.1.1"
CONFIG_URL="https://db33.dev.dinabox.net/upcode/upcode.php" 
AUTH_URL="https://db33.dev.dinabox.net/upcode/upcode.php"

# TODOS os arquivos temporários na pasta organizada
TOKEN_FILE="$UPCODE_TEMP_DIR/token"
USER_FOLDERS_FILE="$UPCODE_TEMP_DIR/user_folders"
USER_INFO_FILE="$UPCODE_TEMP_DIR/user_info"
HISTORY_FILE="$UPCODE_TEMP_DIR/upload_history"

# Arquivos de sincronização TAMBÉM na pasta organizada
SYNC_LOG_FILE="$UPCODE_TEMP_DIR/sync.log"
SYNC_CACHE_FILE="$UPCODE_TEMP_DIR/sync.cache"

USER_CAN_DELETE=""

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
