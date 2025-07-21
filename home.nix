{ config, pkgs, ... }:

{
  home.username      = "arlo";
  home.homeDirectory = "/home/arlo";
  home.stateVersion  = "25.05";

  # User-facing packages
  home.packages = with pkgs; [
    ### Development & Language Tools
    python3 python3Packages.pip 
    R 
    nodejs typescript 
    tailwindcss html-tidy

    ### CLI Utilities & Media Tools
    mpv mpvpaper ytfzf ani-cli
    anki-bin
    pavucontrol
    grim slurp wayshot wl-clipboard cliphist
    curl wget btop brightnessctl kitty keepassxc
  ];

  # Enable and configure programs
  programs = {
    ### Shells & Editors
    zsh.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };

    ### Version Control & Authentication
    git = {
      enable = true;
      userName = "arlohks";
      userEmail = "arlo.hicks@pm.me";
    };
    ssh.startAgent = true;
    gnupg.agent.enable = true;
  };

  home.file = {
    ".config/hypr/hyprland.conf".source = "${dotfiles}/configs/hypr/hyprland.conf";
    ".config/tofi/config.toml".source = "${dotfiles}/configs/tofi/config.toml";
  };

  # Dotfile management, environment variables, etc.
  # e.g., home.file.".config/hypr/hyprland.conf".text = "...";
}
