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
              kubernetes-helm
            ];

            shellHook = ''
              export KUBECONFIG="$(${realpath} ./kubeconfig.yaml)"

              # NOTE: since the pass-operator chart is not public, we add it here as a submodule.
              # FIXME: is there a better way to do this?
              git submodule update --init --recursive
            '';
          };
        }
      );
}
