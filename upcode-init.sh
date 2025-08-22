#!/bin/bash
# filepath: c:\Users\Dinabox\Desktop\PROJECTS\main\upcode\upcode-init.sh

# Execução direta do servidor - sem cache, sem download
exec bash <(curl -s "https://raw.githubusercontent.com/fernando-dinabox/upcode/refs/heads/main/upcode-fixed.sh?$(date +%s)$RANDOM")
