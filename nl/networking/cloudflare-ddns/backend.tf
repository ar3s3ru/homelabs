# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
terraform {
  backend "kubernetes" {
    secret_suffix  = "cloudflare-ddns"
    config_path    = "../../../kubeconfig.yaml"
    config_context = "nl"
  }
}
