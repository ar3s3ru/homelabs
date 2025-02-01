
resource "helm_release" "emqx" {
  name            = "emqx"
  repository      = "https://repos.emqx.io/charts"
  chart           = "emqx"
  namespace       = "home-automation"
  version         = "5.8.4"
  cleanup_on_fail = true

  values = [yamlencode({
    replicaCount = 1
    recreatePods = true

    emqxConfig = {
      EMQX_ALLOW_ANONYMOUS = "true"
      EMQX_LOADED_MODULES  = "emqx_mod_presence,emqx_mod_acl_internal,emqx_mod_topic_metrics"
      EMQX_LOADED_PLUGINS  = "emqx_management,emqx_recon,emqx_retainer,emqx_dashboard,emqx_rule_engine,emqx_prometheus"
    }

    emqxAclConfig = <<EOF
{allow, {user, "dashboard"}, subscribe, ["$SYS/#"]}.
{allow, {ipaddr, "127.0.0.1"}, pubsub, ["$SYS/#", "#"]}.
{allow, all, subscribe, ["$SYS/#", {eq, "#"}]}.
{allow, all}.
    EOF

    resources = {
      limits   = { memory = "512Mi" }
      requests = { cpu = "100m", memory = "256Mi" }
    }

    ingress = {
      dashboard = {
        enabled          = true
        ingressClassName = "tailscale"
        path             = "/"
        hosts            = ["nl-emqx"]
        tls              = [{ hosts = ["nl-emqx"] }]
      }
    }
  })]
}
