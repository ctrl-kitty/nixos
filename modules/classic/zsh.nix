{ pkgs, ... }:

{
  imports = [
	./starship.nix
	./git.nix
  ];
  environment.systemPackages = with pkgs; [
    ghostty
    eza           # Modern ls replacement
    ripgrep       # Fast grep alternative
    fd            # Fast find alternative
    zoxide        # Smart cd command
    dust          # Modern du
    duf           # Modern df
    procs         # Modern ps
    bottom        # Modern top/htop
    direnv        # load .env from curr dir into shell
    yazi          # terminal file manager
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
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first";
      la = "eza -la --icons --group-directories-first";
      lt = "eza --tree --level=2 --icons";
      
      # System management
      update = "sudo nixos-rebuild switch --flake ~/.dotfiles/nixos#RedNixOs";
      clean = "sudo nix-collect-garbage -d && nix store optimise";
      rebuild = "sudo nixos-rebuild build --flake ~/.dotfiles/nixos#RedNixOs";
      upgrade = "sudo nixos-rebuild switch --flake ~/.dotfiles/nixos#RedNixOs --update-input nixpkgs-unstable";
      ptun = "sudo tun2proxy-bin --proxy http://127.0.0.1:2080 --tun ptun";
      
      find = "fd";
      du = "dust";
      df = "duf";
    };

    histSize = 50000;
    histFile = "$HOME/.zsh_history";
    interactiveShellInit = ''
	  bindkey -e
      export KEYTIMEOUT=1
	  eval "$(${pkgs.zoxide}/bin/zoxide init zsh --cmd cd)"
	  # ctrl + left/right
      bindkey "^[[1;5D" backward-word
	  bindkey "^[[1;5C" forward-word
	  # delete
      bindkey "^[[3~"   delete-char
	  # ctrl + backspace
      bindkey "^H"      backward-kill-word
	  # ctrl + delete
      bindkey "^[[3;5~" delete-word
    '';
  };

  programs.fzf = {
	keybindings = true;
	fuzzyCompletion = true;
  };

  users = {
	defaultUserShell = pkgs.zsh;
	extraUsers = {
	  ktvsky.shell = pkgs.zsh;
	  root.shell = pkgs.zsh;
	};
  };

}
