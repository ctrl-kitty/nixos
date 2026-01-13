{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    ghostty
    eza           # Modern ls replacement
    bat           # Modern cat with syntax highlighting
    ripgrep       # Fast grep alternative
    fd            # Fast find alternative
    fzf           # Fuzzy finder
    zoxide        # Smart cd command
    starship      # Beautiful prompt
    dust          # Modern du
    duf           # Modern df
    procs         # Modern ps
    bottom        # Modern top/htop
    direnv        # load .env from curr dir into shell
    yazi          # terminal file manager
    lazygit
    delta
    gh
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    setOptions = [
      "HIST_IGNORE_ALL_DUPS"
      "HIST_FIND_NO_DUPS"
      "HIST_SAVE_NO_DUPS"
      "SHARE_HISTORY"
      "APPEND_HISTORY"
      "INC_APPEND_HISTORY"
      "AUTO_CD"
      "CORRECT"
    ];
    shellAliases = {
      # Modern replacements
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first";
      la = "eza -la --icons --group-directories-first";
      lt = "eza --tree --level=2 --icons";
      cat = "bat --style=auto";
      
      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline --graph --decorate";
      
      # System management
      update = "sudo nixos-rebuild switch --flake ~/.dotfiles/nixos#RedNixOs";
      clean = "sudo nix-collect-garbage -d && nix store optimise";
      rebuild = "sudo nixos-rebuild build --flake ~/.dotfiles/nixos#RedNixOs";
      upgrade = "sudo nixos-rebuild switch --flake ~/.dotfiles/nixos#RedNixOs --update-input nixpkgs-unstable";
      ptun = "sudo tun2proxy-bin --proxy http://127.0.0.1:2080 --tun ptun";
      
      # Productivity
#      grep = "rg";
      find = "fd";
      du = "dust";
      df = "duf";
    };

    histSize = 50000;
    histFile = "$HOME/.zsh_history";
    promptInit = ''
      # Initialize Starship prompt
      eval "$(${pkgs.starship}/bin/starship init zsh)"
    '';

    interactiveShellInit = ''
      # Enable vi mode
      bindkey -v
      export KEYTIMEOUT=1

      # Better history search
      bindkey '^R' history-incremental-search-backward
      bindkey '^S' history-incremental-search-forward

      # FZF integration
      source ${pkgs.fzf}/share/fzf/completion.zsh
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      
      # FZF configuration with beautiful colors
      export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --margin=1 --padding=1 \
        --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 \
        --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 \
        --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 \
        --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
      
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

      # Zoxide integration (smart cd) also note cd=z alias here
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh --cmd cd)"

      # Better paging
      export PAGER='less'
      export LESS='-R --use-color -Dd+r$Du+b'
    '';
  };
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "$nodejs"
        "$python"
        "$rust"
        "$golang"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      directory = {
        style = "bold cyan";
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = " ";
        style = "bold purple";
      };

      git_status = {
        style = "bold yellow";
        conflicted = "⚔️ ";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "🤷 ";
        stashed = "📦 ";
        modified = "📝 ";
        staged = "✅ \${count}";
        renamed = "👅 ";
        deleted = "🗑️ ";
      };

      nix_shell = {
        symbol = " ";
        format = "via [$symbol$state]($style) ";
      };

      cmd_duration = {
        min_time = 500;
        format = "took [$duration](bold yellow)";
      };
    };
  };
  programs.git = {
    enable = true;
    config = {
      core = {
        pager = "delta";
      };
      interactive = {
        diffFilter = "delta --color-only";
      };
      delta = {
        navigate = true;
        line-numbers = true;
        side-by-side = false;
        syntax-theme = "Dracula";
      };
    };
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Set Zsh as default shell
  users.defaultUserShell = pkgs.zsh;

  users.extraUsers.ktvsky = {
    shell = pkgs.zsh;
  };
  users.extraUsers.root = {
    shell = pkgs.zsh;
  };
}
