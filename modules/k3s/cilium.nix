{
  services.k3s.autoDeployCharts.cilium = {
    name = "cilium";
    repo = "https://helm.cilium.io/";
    version = "1.19.3";
    hash = "sha256-rt3TlLpIMTLyN+DZFRpHItt7tadQ3k+BghkfwhI8Yaw=";
    targetNamespace = "kube-system";
    createNamespace = true;
    values = {
      # Replace kube-proxy with eBPF datapath.
      kubeProxyReplacement = true;
      k8sServiceHost = "10.0.1.1";
      k8sServicePort = 6443;

      # IPAM: honour per-node podCIDRs allocated by k3s controller-manager.
      ipam.mode = "kubernetes";

      # Start in VXLAN tunnel mode (mirrors current Flannel overlay).
      # Future follow-up: switch to native routing once Cilium BGP is proven.
      routingMode = "tunnel";
      tunnelProtocol = "vxlan";

      # Dual-stack.
      ipv4.enabled = true;
      ipv6.enabled = true;

      # Masquerade.
      enableIPv4Masquerade = true;
      enableIPv6Masquerade = true;
      bpf.masquerade = true;

      # BGP Control Plane (replaces MetalLB).
      bgpControlPlane.enabled = true;

      # Operator HA.
      operator = {
        replicas = 2;
        prometheus.enabled = true;
      };

      # Hubble observability.
      hubble = {
        enabled = true;
        relay.enabled = true;
        ui = {
          enabled = true;
          ingress = {
            enabled = true;
            className = "tailscale";
            hosts = [ "nl-hubble" ];
            tls = [{ hosts = [ "nl-hubble" ]; }];
          };
        };
        tls.auto = {
          enabled = true;
          method = "helm";
        };
        metrics.enabled = [ "dns" "drop" "tcp" "flow" "icmp" "http" ];
      };

      # Gateway API (parallel to ingress-nginx).
      gatewayAPI.enabled = true;

      # Prometheus metrics for Cilium itself.
      prometheus.enabled = true;

      # Service types handled by Cilium eBPF.
      nodePort.enabled = true;
      externalIPs.enabled = true;
      hostPort.enabled = true;
    };
  };
}
