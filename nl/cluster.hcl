generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "kubernetes" {
    secret_suffix = "${basename(get_working_dir())}"
    config_path   = "${get_path_to_repo_root()}/kubeconfig.yaml"
    config_context = "nl"
  }
}
EOF
}

locals {
  tailscale_domain        = "tail2ff90.ts.net"
  home_assistant_hostname = "nl-hass"
}

inputs = {
  kubernetes_context      = "nl"
  tailscale_domain        = local.tailscale_domain
  authentik_host          = "auth.nl.ar3s3ru.dev"
  home_assistant_hostname = local.home_assistant_hostname
  home_assistant_host     = "${local.home_assistant_hostname}.${local.tailscale_domain}"
  jellyfin_host           = "jellyfin.nl.ar3s3ru.dev"
}
