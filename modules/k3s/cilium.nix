{
  services.k3s.autoDeployCharts.cilium = {
    name = "cilium";
    repo = "https://helm.cilium.io/";
    version = "1.19.3";
    hash = "sha256-yOBd+eq/kBnmL1ED4fNYFLTxtDkW+IUZ5a5ONsaapCs=";
      targetNamespace = "networking";
      createNamespace = true;
      values = {
        # Replace kube-proxy with eBPF datapath.
        kubeProxyReplacement = true;
        k8sServiceHost = "10.0.1.1";
        k8sServicePort = 6443;

        # IPAM: honour per-node podCIDRs allocated by k3s controller-manager.
        ipam.mode = "kubernetes";

        # Native routing mode with autoDirectNodeRoutes (each agent installs
        # host routes to other nodes' pod CIDRs via their node IPs).
        # Tunnel mode caused MSS rewrites that broke etcd peer connectivity.
        routingMode = "native";
        autoDirectNodeRoutes = true;

        # Dual-stack.
        ipv4.enabled = true;
        ipv6.enabled = true;

        # Tell Cilium which CIDRs are pod-native (so host networking is left alone).
        ipv4NativeRoutingCIDR = "10.42.0.0/16";
        ipv6NativeRoutingCIDR = "fd00:cafe:42::/48";

        # Masquerade.
        # bpf.masquerade=true caused severe TCP throughput collapse on the
        # Tailscale-operator-managed proxy pods (laptop ↔ ts-* ↔ ClusterIP).
        # Falling back to iptables masquerade restores parity with kube-proxy
        # behaviour pre-Cilium. Slight perf hit for high-throughput pod→external,
        # but our actual workloads aren't bottlenecked by that.
        enableIPv4Masquerade = true;
        enableIPv6Masquerade = true;
        bpf.masquerade = false;

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
