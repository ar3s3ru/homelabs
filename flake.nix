{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
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
            ];

            shellHook = ''
              export KUBECONFIG="$(${realpath} ./nl/kubeconfig.yaml)"
            '';
          };
        }
      );
}
