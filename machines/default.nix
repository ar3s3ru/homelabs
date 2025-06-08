inputs@{ nixpkgs, sops-nix, disko, ... }:

{
  dejima = import ./dejima inputs;
  eq14-001 = import ./eq14-001 inputs;
  momonoke = import ./momonoke inputs;
  r5c-gateway = import ./r5c-gateway inputs;

  meta.nixpkgs = import nixpkgs {
    system = "x86_64-linux";
    overlays = [ (import ../modules/nix/overlays) ];
  };

  defaults = { pkgs, lib, ... }: {
    imports = [
      disko.nixosModules.disko
      sops-nix.nixosModules.sops
    ];

    system.stateVersion = "23.11";

    # Build in a dedicated folder on the store partition.
    systemd.services.nix-daemon.environment.TMPDIR = "/nix/tmp";

    # Decrypt common secrets.
    sops.defaultSopsFile = ./secrets.yaml;
    sops.defaultSopsFormat = "yaml";

    # Use the latest Linux kernel version by default.
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    # Use unstable Nix.
    nix.package = pkgs.nixVersions.latest;
    nix.extraOptions = "experimental-features = nix-command flakes";
    nix.optimise.automatic = true;

    # Enable direnv.
    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true;

    # Locale.
    i18n.defaultLocale = "en_US.UTF-8";
    console.font = "Lat2-Terminus16";
    console.keyMap = lib.mkForce "us";
    console.useXkbConfig = true; # use xkb.options in tty.

    # Enable fish.
    programs.fish.enable = true;
    programs.fish.shellInit = ''
      direnv hook fish | source
    '';
    programs.fish.shellAliases = {
      cat = "bat";
      du = "duf";
      ls = "eza";
      top = "htop";
      ping = "prettyping --nolegend";
    };

    # Enable container virtualization with Docker.
    virtualisation.docker.enable = true;

    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "yes";

    # Better disk mounting.
    services.udisks2.enable = true;

    # Enable GPG.
    programs.mtr.enable = true;
    programs.gnupg.agent.enable = true;
    programs.gnupg.agent.enableSSHSupport = true;

    # Enable tmux.
    programs.tmux.enable = true;

    # Use Neovim as default editor.
    programs.neovim.enable = true;
    programs.neovim.defaultEditor = true;

    # Create root user and allow SSH sessions from dedicated keys.
    users.mutableUsers = false;
    users.defaultUserShell = pkgs.fish;
    users.users.root.hashedPassword = "$6$IAwKbqRXgvJXNTPI$w8m6U48i5j9kCG9GoMSgeUC5XzIrxz9IA.8EmV91bZdlM.B82zI2.wdxR6SD.U8xBPlm3nIgtJGUvWChD.yYX/";
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOT8pC2k4pixtod7Z7NS3n3qZR+yhR/KCqfVWVlqXysv ar3s3ru@teriyaki.ar3s3ru.dev"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8pfB5IIXKbJQaxezmQ2oC+uJl+dg0MCoFYwcsjhrm+ ar3s3ru@polus"
    ];

    # Packages
    environment.systemPackages = with pkgs; [
      util-linuxMinimal
      wget
      lm_sensors
      ripgrep
      git
      git-crypt
      gnumake
      killall
      unzip
      pciutils
      usbutils
      mscp
      lshw
      inetutils
      tcpdump
      # Fish utilities.
      fzf
      bat
      duf
      eza
      prettyping
      htop
      grc
      # Fish plugins
      # fishPlugins.fzf-fish
      fishPlugins.forgit
      fishPlugins.grc
    ];
  };
}
