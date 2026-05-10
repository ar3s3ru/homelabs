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

      # Force MTU 1500 (Ethernet default). Cilium's auto-detection picks 1280
      # from the host's tailscale0 device, but pod traffic does NOT traverse
      # tailscale0 — it flows through the LAN NICs (1500). The artificially
      # low MTU collapses Tailscale-operator-managed proxy pods to ~18 KB/s
      # because their userspace WG netstack adds another ~140 bytes overhead,
      # leaving an effective application MTU of ~1140 — anything larger gets
      # silently dropped, triggering massive TCP retransmits.
      # See: https://github.com/tailscale/tailscale/issues/18565
      MTU = 1500;

      # Masquerade via eBPF (faster than iptables masquerade).
      enableIPv4Masquerade = true;
      enableIPv6Masquerade = true;
      bpf.masquerade = true;

      # Track IPv4 fragments in the BPF datapath. Without this, BPF drops
      # fragmented packets at egress, which breaks Tailscale userspace WG
      # (MTU 1280) carrying large TCP segments from cluster-internal backends.
      # Observed >350 MB of "Fragmented packet" drops on a single agent.
      fragmentTracking = true;

      # Send ICMP "Fragmentation Needed" so endpoints can do PMTU discovery
      # rather than relying on fragmentation in the first place.
      pmtuDiscovery.enabled = true;

      # BGP Control Plane (replaces MetalLB).
      bgpControlPlane.enabled = true;

      # Operator HA.
      operator = {
        replicas = 2;
        # cilium-operator metrics on :9963. ServiceMonitor lets
        # VictoriaMetrics scrape operator-side stats (LB-IPAM allocation
        # errors, BGP peering events, reconcile latencies).
        # trustCRDsExist=true skips the helm-time CRD precondition check —
        # required when rendered by k3s helm-controller (no cluster
        # context). VictoriaMetrics installs the prometheus-operator CRDs.
        prometheus = {
          enabled = true;
          serviceMonitor = {
            enabled = true;
            trustCRDsExist = true;
          };
        };
      };

      # Hubble observability.
      hubble = {
        enabled = true;
        relay = {
          enabled = true;
          # Expose hubble-relay metrics on :9966 and create a ServiceMonitor
          # so VictoriaMetrics scrapes them. Gives relay-side stats (flows
          # processed, peer connectivity, dropped messages) on top of the
          # per-agent hubble-metrics endpoint below.
          prometheus = {
            enabled = true;
            serviceMonitor = {
              enabled = true;
              trustCRDsExist = true;
            };
          };
        };
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
        # L7 / per-flow metrics exported by each cilium-agent on :9965. The
        # `dns,drop,tcp,flow,icmp,http` set covers DNS errors, dropped
        # packets, TCP flow counts, generic flow events, ICMP, and HTTP
        # request rates + latencies — the L4 + L7 telemetry we need to
        # observe traffic through Cilium Gateway API (Envoy).
        # The ServiceMonitor lets VictoriaMetrics auto-discover the
        # hubble-metrics Service (already created by the chart).
        metrics = {
          enabled = [ "dns" "drop" "tcp" "flow" "icmp" "http" ];
          serviceMonitor = {
            enabled = true;
            trustCRDsExist = true;
          };
        };
      };

      # cilium-envoy proxy metrics on :9964. Required for L7 visibility
      # into Gateway API HTTPRoute traffic (Envoy is the actual data
      # plane). ServiceMonitor flag applies to both cilium-envoy and
      # cilium-agent when Envoy is enabled.
      envoy.prometheus.serviceMonitor = {
        enabled = true;
        trustCRDsExist = true;
      };

      # Gateway API (parallel to ingress-nginx).
      # Sync TLS secrets into the `networking` namespace instead of the
      # default `cilium-secrets`, to keep all networking-related resources
      # co-located with the Cilium release itself.
      gatewayAPI = {
        enabled = true;
        secretsNamespace = {
          name = "networking";
          create = false;
        };
      };

      # Cilium-agent metrics on :9962. ServiceMonitor exposes the per-node
      # eBPF datapath stats (L3/L4 forwarded/dropped packets, NAT, conntrack,
      # endpoint count, BPF map pressure) to VictoriaMetrics.
      prometheus = {
        enabled = true;
        serviceMonitor = {
          enabled = true;
          trustCRDsExist = true;
        };
      };

      # Service types handled by Cilium eBPF.
      nodePort.enabled = true;
      externalIPs.enabled = true;
      hostPort.enabled = true;
    };
  };
}
