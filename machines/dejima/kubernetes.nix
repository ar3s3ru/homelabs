{ pkgs, ... }:

{
  # Add the necessary packages for the Kubernetes experience.
  environment.systemPackages = with pkgs; [
    k3s
    k9s # To have a better experience
    openssl # Used to generate user account CSRs.
    kubectl
    kubernetes-helm
    docker
    runc
  ];

  # NOTE: this is only necessary to be used in case of emergencies, when the Tailnet
  # is down and can't be reached again.
  #
  # You can connect to the k8s cluster through the VPN hostname and port 6443.
  # Remember to use `insecure-skip-tls-verify: true` to make it work.
  networking.firewall.interfaces.eno1.allowedTCPPorts = [ 6443 ];

  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };

  # Kubernetes through K3S.
  services.k3s = {
    enable = true;
    role = "server";
  };
}
