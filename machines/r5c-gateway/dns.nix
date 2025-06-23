{ config, ... }:

{
  services.resolved.enable = false;

  services.unbound.enable = true;
  services.unbound.resolveLocalQueries = true;
  services.unbound.settings = {
    server = {
      interface = [ "192.168.3.1" "127.0.0.1" ];
      access-control = [
        "0.0.0.0/0 refuse"
        "127.0.0.0/8 allow"
        "192.168.0.0/16 allow"
        "::0/0 refuse"
        "::1 allow"
      ];
      private-domain = config.networking.domain;
    };
    forward-zone = [
      {
        name = ".";
        forward-tls-upstream = true; # forward queries with DNS over TLS
        forward-first = false; # don't fallback to recursive DNS
        forward-addr = [
          # forward to cloudflare's DNS
          "1.1.1.1@853#cloudflare-dns.com"
          "1.0.0.1@853#cloudflare-dns.com"
        ];
      }
    ];
  };
}
