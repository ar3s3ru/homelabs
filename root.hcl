generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "kubernetes" {
    secret_suffix  = "${basename(get_terragrunt_dir())}"
    config_path    = "${get_repo_root()}/kube/config.yaml"
    config_context = "nl"
  }
}
EOF
}
