
# Verifica se as dependências estão instaladas
check_dependencies() {
    
    if ! command -v fzf &> /dev/null; then
        echo "❌ FZF não encontrado - tentando instalação automática..."
        
        if install_fzf; then
            echo "✅ FZF instalado!"
            
            # Verificar se funciona
            if ! command -v fzf &> /dev/null; then
                echo "⚠️  Reinicie o terminal ou execute: source ~/.bashrc"
            fi
        else
            echo "❌ Falha na instalação automática. Instale FZF manualmente:"
            echo "📦 Windows: choco install fzf OU scoop install fzf"
            echo "📦 Linux: sudo apt install fzf"
            return 1
        fi
    fi
}



# Função para mostrar barra de progresso
show_progress() {
    local duration=$1
    local message=$2
    
    for ((i=0; i<=duration; i++)); do
        local progress=$((i * 100 / duration))
        local bar=""
        local filled=$((progress / 5))
        
        for ((j=0; j<filled; j++)); do
            bar+="█"
        done
        for ((j=filled; j<20; j++)); do
            bar+="░"
        done
        
        printf "\r$message [%s] %d%%" "$bar" "$progress"
        sleep 0.1
    done
    echo
}

# Instalação automática do Fuzzy Finder (FZF) se não estiver presente
install_fzf() {
    # Verificar se já está instalado
    if command -v fzf &> /dev/null; then
        return 0
    fi
    
    echo "📦 Tentando instalação automática do FZF..."
    echo
    
    # Prioridade: Scoop > Chocolatey > APT > Homebrew > WinGet (último recurso)
    if command -v scoop &> /dev/null; then
        echo "🔄 Tentando instalação via Scoop..."
        
        show_progress 20 "   Instalando FZF" &
        local progress_pid=$!
        
        if timeout 45s scoop install fzf 2>/dev/null; then
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Instalando FZF [████████████████████] 100%%\n"
            echo "✅ FZF instalado com sucesso via Scoop!"
            return 0
        else
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Instalando FZF [░░░░░░░░░░░░░░░░░░░░] FALHOU\n"
            echo "❌ Falha na instalação via Scoop"
        fi
    fi
    
    if command -v choco &> /dev/null; then
        echo "🔄 Tentando instalação via Chocolatey..."
        
        # Mostrar progresso em background
        show_progress 30 "   Instalando FZF" &
        local progress_pid=$!
        
        # Tentar instalação com timeout e forçar confirmações
        if timeout 60s choco install fzf -y --force --accept-license --confirm 2>/dev/null; then
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Instalando FZF [████████████████████] 100%%\n"
            echo "✅ FZF instalado com sucesso via Chocolatey!"
            return 0
        else
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Instalando FZF [░░░░░░░░░░░░░░░░░░░░] FALHOU\n"
            echo "❌ Falha na instalação via Chocolatey"
        fi
    fi
    
    if command -v apt &> /dev/null; then
        echo "🔄 Tentando instalação via APT..."
        
        show_progress 25 "   Atualizando repositórios e instalando FZF" &
        local progress_pid=$!
        
        if timeout 60s sudo apt update -qq && timeout 60s sudo apt install -y fzf 2>/dev/null; then
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Atualizando repositórios e instalando FZF [████████████████████] 100%%\n"
            echo "✅ FZF instalado com sucesso via APT!"
            return 0
        else
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Atualizando repositórios e instalando FZF [░░░░░░░░░░░░░░░░░░░░] FALHOU\n"
            echo "❌ Falha na instalação via APT"
        fi
    fi
    
    if command -v brew &> /dev/null; then
        echo "🔄 Tentando instalação via Homebrew..."
        
        show_progress 25 "   Instalando FZF" &
        local progress_pid=$!
        
        if timeout 60s brew install fzf 2>/dev/null; then
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Instalando FZF [████████████████████] 100%%\n"
            echo "✅ FZF instalado com sucesso via Homebrew!"
            return 0
        else
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Instalando FZF [░░░░░░░░░░░░░░░░░░░░] FALHOU\n"
            echo "❌ Falha na instalação via Homebrew"
        fi
    fi
    
    if command -v winget &> /dev/null; then
        echo "🔄 Tentando instalação via WinGet (último recurso)..."
        
        show_progress 35 "   Instalando FZF" &
        local progress_pid=$!
        
        if timeout 90s winget install --id=junegunn.fzf --accept-package-agreements --accept-source-agreements 2>/dev/null; then
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Instalando FZF [████████████████████] 100%%\n"
            echo "✅ FZF instalado com sucesso via WinGet!"
            return 0
        else
            kill $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            printf "\r   Instalando FZF [░░░░░░░░░░░░░░░░░░░░] FALHOU\n"
            echo "❌ Falha na instalação via WinGet"
        fi
    fi
    
    echo "❌ Nenhum gerenciador de pacotes conseguiu instalar o FZF"
    echo "📋 Instale FZF manualmente:"
    echo "   Windows: choco install fzf  OU  scoop install fzf"
    echo "   Linux: sudo apt install fzf"
    echo "   Mac: brew install fzf"
    return 1
}
