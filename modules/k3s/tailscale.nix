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

  services.k3s.autoDeployCharts.tailscale-operator = rec {
    name = "tailscale-operator";
    repo = "https://pkgs.tailscale.com/helmcharts";
    version = "1.96.5";
    hash = "sha256-BtZ24mCT2GMHE9iR+2xuIkB+4m1r2OC3WLkY3jC3i3I=";
    targetNamespace = "networking";
    extraFieldDefinitions = {
      spec = {
        inherit version;
      };
    };
    values = {
      operatorConfig.hostname = "nl-k8s";
      apiServerProxyConfig.mode = "true";
    };
  };
}
