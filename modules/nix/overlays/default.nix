final: prev: {
  # Source: https://github.com/NixOS/nixpkgs/pull/405952/files
  util-linux = prev.util-linux.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      # https://github.com/util-linux/util-linux/pull/3479 (fixes https://github.com/util-linux/util-linux/issues/3474)
      ./fix-mount-regression.patch
    ];
  });
}
