{ lib, config, ... }:

{
  # Disable limits for the number of open files by k3s containers,
  # or the telemetry stack will complain.
  systemd.services.k3s.serviceConfig.LimitNOFILE = lib.mkIf config.services.k3s.enable (lib.mkForce null);
  systemd.services.k3s.serviceConfig.LimitNOFILESoft = lib.mkIf config.services.k3s.enable (lib.mkForce null);
  systemd.services.containerd.serviceConfig.LimitNOFILE = lib.mkIf config.services.k3s.enable (lib.mkForce null);
}
