final: prev: {
  # Source: https://github.com/NixOS/nixpkgs/pull/405952/files
  k3s = prev.k3s.override {
    util-linux = prev.util-linuxMinimal.overrideAttrs (old: {
      patches = old.patches or [ ] ++ [
        ./fix-mount-regression.patch
      ];
    });
  };
}
