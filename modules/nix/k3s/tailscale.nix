{ config, ... }:

{
  sops.secrets."tailscale/oauth-client-id".sopsFile = ./secrets.yaml;
  sops.secrets."tailscale/oauth-client-secret".sopsFile = ./secrets.yaml;

  sops.templates.tailscale-operator-oauth = {
    path = "/var/lib/rancher/k3s/server/manifests/01-tailscale-operator-oauth.json";
    content = builtins.toJSON {
      apiVersion = "v1";
      kind = "Secret";
      metadata = {
        name = "operator-oauth";
        namespace = "networking";
      };
      stringData = {
        "client_id" = config.sops.placeholder."tailscale/oauth-client-id";
        "client_secret" = config.sops.placeholder."tailscale/oauth-client-secret";
      };
    };
  };

  services.k3s.autoDeployCharts.tailscale-operator = {
    # NOTE: switched to the "unstable" Helm chart to fix https://github.com/tailscale/tailscale/issues/15081
    name = "tailscale-operator";
    repo = "https://pkgs.tailscale.com/unstable/helmcharts";
    version = "1.85.21";
    hash = "sha256-oPAV1s2Yn+oeT6xzYQEDhhf0dy/kMacmbvewQiWsMSw=";
    targetNamespace = "networking";
    values = {
      operatorConfig.hostname = "nl-k8s";
      apiServerProxyConfig.mode = "true";
    };
  };
}
