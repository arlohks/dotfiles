# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let

  ### Hosts file setup
  # 1. Fetch raw StevenBlack hosts file
  stevenBlackHosts = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts";
    sha256 = "04f3hcpykgg1a8il0gsy2wzxq0khbfb15f2ahbngjwfp4hxb0zzp";
  };

  # 2. Strip comments & IPs, leave only domains
  stevenBlackBlocklist = pkgs.runCommand "stevenblack-blocklist.txt" { } ''
    grep -vE '^#|localhost|127\.0\.0\.1' ${stevenBlackHosts} |
      awk '{ print $2 }' | sort -u > $out
  '';

  # 3. Fetch the blocklist-generation script
  blocklistScript = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/utils/generate-domains-blocklist/generate-domains-blocklist.py";
    sha256 = "0npjhixppa3ghzjf4fs338s9n4ralaig76fssbrl1mcmk0yp3n7d";
  };

  ## Create empty allow list & time restriction files to prevent errors
  allowlistFile = pkgs.writeText "domains-allowlist.txt" ''
    reddit.com
    *.reddit.com
    instagram.com
    *.instagram.com
    linkedin.com
    *.linkedin.com
  '';
  timeRestrictedFile = pkgs.writeText "domains-time-restricted.txt" "";

  # 4. Create a plain-text config listing our filtered file
  blocklistConfig = pkgs.writeText "blocklist-config.txt" ''
    file:${stevenBlackBlocklist}
  '';

  # 5. Run the script to produce a wildcard-capable blocklist
  generatedBlocklist = pkgs.runCommand "domains-blocklist.txt" { buildInputs = [ pkgs.python3 ]; } ''
    python3 ${blocklistScript} \
      --config ${blocklistConfig} \
      --allowlist ${allowlistFile} \
      --time-restricted ${timeRestrictedFile} \
      --output-file $out
  '';

in {

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    # Enable networking
    networkmanager = {
      enable = true;
      dns = "none";
    };
    hostName = "nixos"; # Define your hostname.
    wireless.enable = false;  # Enables wireless support via wpa_supplicant.
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };
    nameservers = [ "127.0.0.1" ];
  };

  systemd = {
    network.enable = false;
    services.dnscrypt-proxy2 = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Enable the X11 windowing system.
  services = {
    resolved.enable = false; # disable systemd-resolved if it conflicts
    xserver = {
      xkb.layout = "gb";
      xkb.variant = "";
      enable = false;
      displayManager.gdm.enable = false;
      desktopManager.gnome.enable = false;
      videoDrivers = [ "intel" ];
    };

    # greetd login manager
#    greetd = {
#      enable = true;
#      settings = rec {
#        initial_session = {
#          command = "${pkgs.hyprland}/bin/Hyprland";
#          user = "arlo";
#	};
#        default_session = initial_session; # Auto-login into Hyprland without prompting
#      };
      # Disable automatic restarts when using autologin
#      bestart = false; # otherwise greetd will re-trigger autologin on exit
#    };

    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 20;
        START_CHARGE_THRESH_BAT0 = 40; # Start charging below 40%
        STOP_CHARGE_THRESH_BAT0 = 80;  # Stop charging above 80%
      };
    };

    power-profiles-daemon.enable = false;

  # Power-saving
  # Thermald
    thermald.enable = true;

    auto-cpufreq.enable = true;
    auto-cpufreq.settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };
      charger = {
        governor = "performance";
	turbo = "auto";
      };
    };

  # Enable CUPS to print documents.
    printing.enable = true;

    # Security with DNS-over-HTTPS and malware blocking
    dnscrypt-proxy2 = {
      enable = true;
      settings = {
	ipv6_servers = false;
	require_dnssec = true;

        # Block known bad domains from StevenBlack
        blocked_names = { 
	  blocked_names_file = "${generatedBlocklist}";
	};
	
	# Use a secure DoH resolver
	server_names = [ "cloudflare" ];

	# Optional filters
	cache = true;
	block_ipv6 = true;
      };
    };
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      #jack.enable = true;
    };
  };

  system.userActivationScripts.clearTofiCache = {
    text = ''
      # !/usr/bin/env bash
      rm -f "$HOME/.cache/tofi-drun" "$HOME/.cache/tofi-compgen"
    '';
    # optional dependency ordering:
    deps = [ ];   # leave empty – script is trivial
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Security & Privacy
  security = {
    # Change sudo to doas
    sudo.enable = false;
    doas.enable = true;
    doas.extraRules = [
      { users = [ "arlo" ]; keepEnv = true; persist = true; }
    ];

    # Hardened kernel options
    apparmor.enable = true;
    audit.enable = true;

    # Enable sound with pipewire
    rtkit.enable = true;
  };
  
  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restirct" = 1;
  };

  # Use DNS-over-HTTPS and malware blocking



  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.arlo = {
    isNormalUser = true;
    description = "Arlo";
    shell = pkgs.zsh; # change with pkgs.fish or pkgs.zsh later
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

  environment.variables = {
    # Cursor
    XCURSOR_THEME = "apple-cursor";
    XCURSOR_SIZE = "32";
    HYPRCURSOR_THEME = "apple-cursor";
    HYPRCURSOR_SIZE = "32";

    ### Toolkit Backends & Portals
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";

    # Electron-based apps (Vesktop, VSCode, etc.)
    NIXOS_OZONE_WL = "1";
    OZONE_PLATFORM_HINT = "wayland";

    # GTK apps
    GDK_BACKEND = "wayland,x11";
    GTK_USE_PORTAL = "1";

    # Qt apps (VLC, qBittorrent, etc.)
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

    # Firefox
    MOZ_ENABLE_WAYLAND = "1";

    ### Graphics & Rendering
    AQ_DRM_DEVICES = "/dev/dri/card1";
    EGL_PLATFORM = "wayland";
    LIBVA_DRIVER_NAME = "iHD";

    # Hyprland-specific/XDG compliance
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";

    ### Miscellaneous
    _JAVA_AWT_WM_NONREPARENTING = "1";
    CLUTTER_GL_FORCE_SYNC = "1";
  };

#  xsession.pointCursor = {
#    package = pkgs.apple-cursor;
#    name = "apple-cursor";
#    size = 32;
#  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  
  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
    };
    zsh.enable = true; # in home.nix
    steam = {
      enable = false;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
    };
    firefox.enable = false;
    git.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    nano.enable = false;
    waybar.enable = true;
#    gnupg.agent.enable = true;
#    ssh.startAgent = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    ### Themes & Appearance 
    papirus-icon-theme adwaita-icon-theme lxappearance apple-cursor uwsm

    ### GUI Applications
    ungoogled-chromium vesktop thunderbird spotify
    # spotify whatsapp-for-linux gnome.nautilus gnome.gnome-calendar

    ### Hyprland Utilities 
    hyprlock hypridle waylock wlogout swayosd swaynotificationcenter swww tofi # launcher, bar, wallpaper daemon

    ### Screenshot & Clipboard (Wayland)
    wl-clipboard cliphist wayshot grim slurp # in home.nix

    ### File & Disk Utilities
    ncdu plocate macchina fastfetch

    ### Languages
#    python3 python3Packages.pip R nodejs typescript tailwindcss html-tidy # in home.nix

    ### Media Tools
#    mpv mpvpaper anki-bin ytfzf ani-cli pavucontrol # in home.nix

    ### System Utilities
#    wget curl btop brightnessctl mesa kitty # in home.nix
    kitty
    mesa
    home-manager

    ### Misc
#    keepassxc # in home.nix
  ];


  fonts.packages = with pkgs; [
#    noto-fonts
#    noto-fonts-cjk
#    noto-fonts-emoji
#    jetbrains-mono
#    fira-code
    roboto-mono
    font-awesome
    noto-fonts-cjk-sans
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
