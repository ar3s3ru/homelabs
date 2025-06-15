{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
    colmena.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = inputs@{ nixpkgs, flake-utils, colmena, self, ... }:
    {
      colmena = import ./machines inputs;
      colmenaHive = colmena.lib.makeHive self.outputs.colmena;
      nixosConfigurations = self.outputs.colmenaHive.nodes;
    } // flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          realpath = "${pkgs.coreutils}/bin/realpath";
        in
        {
          devShell = with pkgs; mkShellNoCC {
            packages = [
              nil
              nixpkgs-fmt
              gnumake
              git-crypt
              terraform
              terragrunt
              kubectl
              k9s
              kubernetes-helm
              tfk8s
              ssh-to-age
              sops
              inetutils
              authelia # For management purposes.
            ];

            shellHook = ''
              export KUBECONFIG="$(${realpath} ./clusters/kubeconfig.yaml)"
            '';
          };
        }
      );
}
