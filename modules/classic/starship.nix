{ lib, pkgs, ... }:
{
  # why not imclude in enable option??? https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/programs/starship.nix
  environment.systemPackages = with pkgs; [
    starship
  ];
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

      cmd_duration = {
        min_time = 500;
      };
    };
  };
}
