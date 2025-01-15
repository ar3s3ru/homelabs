include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "tailscale" { # Necessary for Ingress class name.
  config_path  = "../../networking/tailscale"
  skip_outputs = true
}
