include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "cert-manager" { # Necessary for TLS certificates.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/networking/cert-manager"
  skip_outputs = true
}

dependency "cloudflare-ddns" { # Necessary to ensure DNS records are set.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/networking/cloudflare-ddns"
  skip_outputs = true
}

dependency "prowlarr" { # Ensure the indexer dependency is up.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/media/prowlarr"
  skip_outputs = true
}

dependency "sonarr" { # Ensure the TV media fetcher dependency is up.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/media/sonarr"
  skip_outputs = true
}

dependency "reloader" { # Necessary for ConfigMap watcher and StatefulSet reloader.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/reloader"
  skip_outputs = true
}
