#!/bin/bash
# filepath: upcode-init.sh

# URL do script principal (usando a URL raw correta)
MAIN_SCRIPT_URL="https://github.com/fernando-dinabox/upcode/blob/main/upcode-init.sh"

# Baixar e executar o script principal
curl -s "$MAIN_SCRIPT_URL" | bash
