{ config, pkgs, inputs, ... }:
let
  bikeability-tileserver-port = 8000;
  bikeability-client-port = 8001;
  wireguardIP = "10.100.0.2";
  sshPort = 22;
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      "${inputs.home-manager}/nixos"
    ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/mmcblk0";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "nixnas"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  services.logind.lidSwitchExternalPower = "ignore";

  services.openssh = {
    enable = true;
    openFirewall = false;
    listenAddresses = [
      {
        addr = wireguardIP;
        port = sshPort;
      }
    ];
  };

  networking = {
    firewall = {
      interfaces = {
        wg0 = {
          allowedTCPPorts = [
            bikeability-tileserver-port
            bikeability-client-port
            sshPort
          ];
          allowedUDPPorts = [
            config.networking.wireguard.interfaces.wg0.listenPort
          ];
        };
      };
    };
    wireguard = {
      enable = true;
      interfaces = {
        wg0 = {
          ips = [ "${wireguardIP}/24" ];
          listenPort = 51820;

          privateKeyFile = "/Block/wireguard-keys/private";

          peers = [
            {
              publicKey = "raOzdkhoag+sN2/KXz18F9ncmeTWhdmPJxQJkqsJ7FI=";
              allowedIPs = [ "10.100.0.0/24" ];
              endpoint = "50.116.49.95:51820";
              persistentKeepalive = 25;
            }
          ];
        };
      };
    };
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.clhickey = {
    isNormalUser = true;
    description = "Clayton Hickey";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "clhickey";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    inputs.cnvim.packages.x86_64-linux.default
    wget
    tilemaker
    osmium-tool
    osmctools
    mbtileserver
    git
    gh
    htop
    wireguard-tools
    fastfetch
  ];

  systemd = {
    services = {
      bikeability-tileserver = {
        description = "bikeability-tileserver.claytonhickey.me";
        wantedBy = [ "default.target" ];
        script = ''#!/bin/sh
          cd /Block/bikeability &&
          ${pkgs.mbtileserver}/bin/mbtileserver --host ${wireguardIP} --port ${builtins.toString bikeability-tileserver-port}
        '';
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."bikeability-client" = {
      listen = [ { addr = wireguardIP; port = bikeability-client-port; } ];
      locations."/" = {
        root = "/Block/bikeability/bikeability-client/";
      };
    };
  };

  home-manager.users.clhickey = { pkg, ... }: {
    wayland.windowManager.hyprland= {
      enable = true;
      settings = {
        env = [
          "GDK_BACKEND,wayland,x11,*"
          "QT_GPA_PLATFORM,wayland;xcb"
          "SDL_VIDEODRIVER,wayland"
          "CLUTTER_BACKEND,wayland"
        ];
        "$terminal" = "${pkgs.alacritty}/bin/alacritty";
        "exec-once" = [
          #"${pkgs.waybar}/bin/waybar"
        ];
        "$mod" = "SUPER";
        bind = [
          "$mod, RETURN, exec, $terminal"
          "$mod, Q, killactive"
          "$mod&SHIFT, Q, forcekillactive"
          "$mod, E, exec, ${pkgs.wofi}/bin/wofi --show run"
          "$mod, F, fullscreen, 0"
          "$mod&SHIFT, W, movewindow, u"
          "$mod&SHIFT, A, movewindow, l"
          "$mod&SHIFT, S, movewindow, d"
          "$mod&SHIFT, D, movewindow, r"
          "$mod, W, movefocus, u"
          "$mod, A, movefocus, l"
          "$mod, S, movefocus, d"
          "$mod, D, movefocus, r"
          "$mod, space, togglefloating"
        ]++ (
          builtins.concatLists (
            builtins.genList (i:
              [
                "$mod, code:1${toString i}, workspace, ${toString (i+1)}"
                "$mod SHIFT, code:1${toString i}, movetoworkspacesilent, ${toString (i+1)}"
              ]
            )
            9
          )
        );
        general = {
          gaps_in = 0;
          gaps_out = 0;
        };
        input = {
          accel_profile = "flat";
          sensitivity = 1.0;
        };
      };
    };

    services.hyprpolkitagent.enable = true;

    home.stateVersion = "24.11";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "24.11"; # Did you read the comment?

}
