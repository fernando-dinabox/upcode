
    # Detectar diretório do script atual
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local ORIGINAL_DIR="$PWD"
    
    # Navegar para o diretório do upcode
    cd "$SCRIPT_DIR" || {
        echo "❌ Erro: Não foi possível navegar para o diretório upcode"
        return 1
    }
    # Carregar style
    source ../config/fzf_style.sh

    # Carregar os scripts da pasta src
    source ../config/auth.sh
    source src/utils.sh
    source ../config/dependencies.sh
    source src/menus.sh
    source src/navigation.sh
    source src/uploads.sh
    source src/sync.sh

    CURRENT_VERSION="1.0.4"
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

    # Configurações de interface
    set_fzf_style
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
