{ lib, ... }:

{
  imports = [
    ./k3s.nix
  ];

  # Kubernetes through K3S.
  services.k3s.role = "server";
  services.k3s.extraFlags = lib.mkBefore [
    # Using ingress-nginx instead.
    "--disable=traefik"
    # Dual-stacking it - it's 2025, let's use IPv6.
    "--cluster-cidr=10.42.0.0/16,fd00:cafe:42::/48"
    "--service-cidr=10.43.0.0/16,fd00:cafe:43::/112"
    "--flannel-ipv6-masq" # Enable IPv6 NAT, as per default pods use their pod IPv6 address for outgoing traffic
  ];
}
