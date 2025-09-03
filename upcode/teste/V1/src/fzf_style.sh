    # Função utilitária para configurar opções do FZF facilmente
    set_fzf_style() {
        # Configurações de interface em um array associativo para fácil manutenção
        declare -gA FZF_OPTS=(
            [height]="20%"                # Altura do menu
            [border]="bold"            # Tipo borda
            [margin]="1"                # Margem
            [color_fg]="#ffffff"          # fg: Branco (Texto principal)
            #[color_bg]="#222222"          # bg: Cinza escuro (Fundo)
            [color_hl]="#ff79c6"          # hl: Rosa (Highlight/seleção)
            [color_border]="#8be9fd"      # border: Azul claro (Borda)
            [color_info]="#8be9fd"        # info: Azul claro (Informações)
            [color_prompt]="#ff6347"      # prompt: Azul claro (Prompt)
            [color_header]="#222222"      # header: Cinza escuro (Cabeçalho)
            [color_pointer]="#ffb86c"     # pointer: Laranja (Ponteiro de seleção)
            [color_marker]="#50fa7b"      # marker: Verde (Marcador de seleção múltipla)
            [color_spinner]="#bd93f9"     # spinner: Roxo (Spinner de carregamento)
            [color_preview_bg]="#222222"  # preview-bg: Cinza escuro (Fundo da prévia)
            #[preview]="[[ -d {} ]] && ls -lh --color=always {} || cat {}"  # Mostra conteúdo da pasta ou arquivo
            #[preview_window]="right:50%"  # Configuração da janela de prévia
            [layout]="default"            # Layout do menu
            [cycle]="--cycle"             # Navegação cíclica
            [multi]="--multi"             # Seleção múltipla
            [header]="Selecione um item"  # Texto do cabeçalho
            [prompt]="> "                 # Texto do prompt
        )

        # Monta FZF_DEFAULT_OPTS a partir do array
        FZF_DEFAULT_OPTS="--height=${FZF_OPTS[height]} \
            --border=${FZF_OPTS[border]} \
            --margin=${FZF_OPTS[margin]} \
            --color=fg:${FZF_OPTS[color_fg]},bg:${FZF_OPTS[color_bg]},hl:${FZF_OPTS[color_hl]},border:${FZF_OPTS[color_border]},info:${FZF_OPTS[color_info]},prompt:${FZF_OPTS[color_prompt]},header:${FZF_OPTS[color_header]},pointer:${FZF_OPTS[color_pointer]},marker:${FZF_OPTS[color_marker]},spinner:${FZF_OPTS[color_spinner]},preview-bg:${FZF_OPTS[color_preview_bg]} \
            --preview='${FZF_OPTS[preview]}' \
            --preview-window='${FZF_OPTS[preview_window]}' \
            --layout=${FZF_OPTS[layout]} \
            ${FZF_OPTS[cycle]} \
            ${FZF_OPTS[multi]} \
            --header='${FZF_OPTS[header]}' \
            --prompt='${FZF_OPTS[prompt]}'"

        export FZF_DEFAULT_OPTS
    }




    # --height=           # Altura do menu (ex: 40%, 10)
    # --border=           # Tipo de borda (ex: rounded, sharp, bold)
    # --margin=           # Margem ao redor do menu (ex: 1, 0, "1,2")
    # --color=            # Personalização de cores:
    #     fg:             # Cor do texto principal
    #     bg:             # Cor de fundo
    #     hl:             # Cor do texto destacado (highlight)
    #     border:         # Cor da borda
    #     info:           # Cor das informações
    #     prompt:         # Cor do prompt
    #     header:         # Cor do cabeçalho
    #     pointer:        # Cor do ponteiro de seleção
    #     marker:         # Cor do marcador de seleção múltipla
    #     spinner:        # Cor do spinner de carregamento
    #     preview-bg:     # Cor de fundo da prévia
    # --preview=          # Comando para mostrar prévia do item selecionado
    # --preview-window=   # Configuração da janela de prévia (ex: right:50%)
    # --layout=           # Layout do menu (default, reverse, reverse-list)
    # --cycle            # Permite navegação cíclica nos itens
    # --multi            # Permite seleção múltipla
    # --header=           # Texto do cabeçalho
    # --prompt=           # Texto do prompt
