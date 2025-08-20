#!/bin/bash
# filepath: upcode-main.sh (no seu repositório)

# Menu de login
echo "🔐 Sistema de Upload - Login necessário"
echo "─────────────────────────────────────"

read -p "👤 Usuário: " username
read -s -p "🔑 Senha: " password
echo

# Validação
if [[ -z "$username" || -z "$password" ]]; then
    echo "❌ Usuário e senha são obrigatórios!"
    exit 1
fi

# Configurações
CONFIG_URL="https://db33.dev.dinabox.net/upcode.php"
CONFIG_PASTA="Endpoint configuração Máquinas"
CONFIG_ARQUIVO="/mnt/c/Users/Dinabox/Desktop/PROJECTS/Endpoints/db_cut_prefers.php"

echo "🚀 Iniciando processo de upload..."

# Verificar se arquivo existe
if [[ ! -f "$CONFIG_ARQUIVO" ]]; then
    echo "❌ Arquivo não encontrado: $CONFIG_ARQUIVO"
    exit 1
fi

# Gerar token (adapte conforme sua autenticação)
TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2RiMzMuZGV2LmRpbmFib3gubmV0IiwiaWF0IjoxNzU1NTE0MTM1LCJuYmYiOjE3NTU1MTQxMzUsImV4cCI6MTc1NTU1MDEzNSwiZGF0YSI6eyJ1c2VyIjp7ImlkIjo5MTMwfX19.es49sjycXt0RQ2MkmhURcF7tNTU3TwMtFRkBwJaVXBo"

echo "📤 Enviando arquivo..."

# Upload
response=$(curl -s -X POST \
    -H "Cookie: jwt_user=$TOKEN; user_jwt=$TOKEN" \
    -F "arquivo[]=@$CONFIG_ARQUIVO" \
    -F "pasta=$CONFIG_PASTA" \
    "$CONFIG_URL")

# Status
filename=$(basename "$CONFIG_ARQUIVO")
if echo "$response" | grep -q "Arquivos enviados com sucesso"; then
    echo "✅ $filename - Enviado com sucesso"
elif echo "$response" | grep -q "Usuário autenticado"; then
    echo "⚠️ $filename - Autenticado mas sem confirmação"
else
    echo "❌ $filename - Erro no upload"
fi

echo "🎉 Processo finalizado!"