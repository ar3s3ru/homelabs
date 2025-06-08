include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cluster" {
  path = find_in_parent_folders("cluster.hcl")
}

dependency "home-automation" { # Creates the namespace.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/home-automation"
  skip_outputs = true
}

dependency "emqx" { # Necessary for MQTT broker.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/home-automation/emqx"
  skip_outputs = true
}

dependency "akri" { # Necessary for node device discovery.
  config_path  = "${get_path_to_repo_root()}/clusters/nl/kube-system/akri"
  skip_outputs = true
}
