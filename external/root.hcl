# NOTE(ar3s3ru): using nl cluster for remote state management.
# Maybe worth moving this elsewhere?
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "kubernetes" {
    secret_suffix = "${basename(get_working_dir())}"
    config_path   = "${get_path_to_repo_root()}/kubeconfig.yaml"
    config_context = "nl"

    # NOTE: read the notes in the "kubernetes" provider.
    # config_context = "nl-private-admin-init"
  }
}
EOF
}
