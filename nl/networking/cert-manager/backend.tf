# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
terraform {
  backend "kubernetes" {
    secret_suffix = "cert-manager"
    config_path   = "../../../kubeconfig.yaml"
    config_context = "nl"

    # NOTE: read the notes in the "kubernetes" provider.
    # config_context = "nl-private-admin-init"
  }
}
