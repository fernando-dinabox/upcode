#!/bin/bash

CACHE_FILE="$HOME/.upcode_cached.sh"
SERVER_URL="https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh"

# SEMPRE verificar e baixar a versão mais recente
curl -s "$SERVER_URL" > "$CACHE_FILE" 2>/dev/null && chmod +x "$CACHE_FILE"

# Executar versão baixada
[[ -f "$CACHE_FILE" ]] && exec bash "$CACHE_FILE" "$@"
