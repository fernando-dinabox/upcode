#!/bin/bash
source src/dependencies.sh
source src/utils.sh      
source src/auth.sh
source src/uploads.sh
source src/testing.sh
source src/menus.sh     
source src/sync.sh
#===========================================
# CONFIGURAÇÕES
#===========================================
CURRENT_VERSION="1.0.4"
CONFIG_URL="https://db33.dev.dinabox.net/upcode/upcode.php" 
AUTH_URL="https://db33.dev.dinabox.net/upcode/upcode.php"  
TOKEN_FILE="$HOME/.upcode_token"
HISTORY_FILE="$HOME/.upcode_history"
SYNC_CONFIG_FILE="$HOME/.upcode_sync_config"
SYNC_CACHE_FILE="$HOME/.upcode_sync_cache"
SYNC_LOG_FILE="$HOME/.upcode_sync_debug.log"
USER_FOLDERS_FILE="$HOME/.upcode_user_folders" 
USER_INFO_FILE="$HOME/.upcode_user_info" 
USER_CAN_DELETE=""
SYNC_PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/upcode_sync.pid"
SYNC_STATUS_FILE="${XDG_RUNTIME_DIR:-/tmp}/upcode_sync_status"


# Array para arquivos selecionados
declare -a selected_files=() # Array para arquivos selecionados
declare -a user_folders=()  # Array para as pastas do usuário

# Variáveis para dados do usuário logado
USER_DISPLAY_NAME=""
USER_NICENAME=""
USER_EMAIL=""
USER_TYPE=""

# Configurações de interface
FZF_DEFAULT_OPTS="--height=40% --border --margin=1 --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9"

#===========================================
# Inicialização 
#===========================================


# Chamar verificação no início
force_update_check
show_banner
check_dependencies
check_token
main_menu