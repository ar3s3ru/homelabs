{ config, ... }:

{
  # Main group for media access.
  # We use this to give access to all users related to media stuff.
  users.groups.media = {
    members = [
      "root"
      config.services.jellyfin.user
      config.services.transmission.user
    ];
  };

  services.jellyfin.group = "media";
  services.transmission.group = "media";
}
