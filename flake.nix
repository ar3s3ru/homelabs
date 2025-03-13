{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ nixpkgs, flake-utils, self, ... }:
    {
      colmena = import ./machines inputs;
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
              colmena
            ];

            shellHook = ''
              export KUBECONFIG="$(${realpath} ./kubeconfig.yaml)"
            '';
          };
        }
      );
}
