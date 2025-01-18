resource "cloudflare_record" "nl_records" {
  for_each = toset([
    "auth.nl",
    "jellyfin.nl"
  ])

  name    = each.key
  zone_id = data.cloudflare_zone.ar3s3ru_dev.id
  comment = "Public service hosted on the nl cluster"
  type    = "CNAME"
  value   = "momonoke.ar3s3ru.dev"
}
