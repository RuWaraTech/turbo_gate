# dns.tf - Hetzner DNS Zone Configuration

# Create the DNS zone
resource "hcloud_dns_zone" "main" {
  name = "ridebase.app"
  ttl  = 3600
}

# A Records - Replace with your Load Balancer IP once created
resource "hcloud_dns_record" "root" {
  zone_id = hcloud_dns_zone.main.id
  name    = "@"
  value   = hcloud_load_balancer.main[0].ipv4  # This will use your LB IP
  type    = "A"
  ttl     = 600
}

resource "hcloud_dns_record" "www" {
  zone_id = hcloud_dns_zone.main.id
  name    = "www"
  value   = hcloud_load_balancer.main[0].ipv4  # This will use your LB IP
  type    = "A"
  ttl     = 600
}

# CNAME Records
resource "hcloud_dns_record" "autodiscover" {
  zone_id = hcloud_dns_zone.main.id
  name    = "autodiscover"
  value   = "autodiscover.outlook.com."
  type    = "CNAME"
  ttl     = 3600
}

resource "hcloud_dns_record" "email" {
  zone_id = hcloud_dns_zone.main.id
  name    = "email"
  value   = "email.secureserver.net."
  type    = "CNAME"
  ttl     = 3600
}

resource "hcloud_dns_record" "lyncdiscover" {
  zone_id = hcloud_dns_zone.main.id
  name    = "lyncdiscover"
  value   = "webdir.online.lync.com."
  type    = "CNAME"
  ttl     = 3600
}

resource "hcloud_dns_record" "msoid" {
  zone_id = hcloud_dns_zone.main.id
  name    = "msoid"
  value   = "clientconfig.microsoftonline-p.net."
  type    = "CNAME"
  ttl     = 3600
}

resource "hcloud_dns_record" "sip" {
  zone_id = hcloud_dns_zone.main.id
  name    = "sip"
  value   = "sipdir.online.lync.com."
  type    = "CNAME"
  ttl     = 3600
}

resource "hcloud_dns_record" "domainconnect" {
  zone_id = hcloud_dns_zone.main.id
  name    = "_domainconnect"
  value   = "_domainconnect.gd.domaincontrol.com."
  type    = "CNAME"
  ttl     = 3600
}

# MX Record
resource "hcloud_dns_record" "mx" {
  zone_id = hcloud_dns_zone.main.id
  name    = "@"
  value   = "0 ridebase-app.mail.protection.outlook.com."
  type    = "MX"
  ttl     = 3600
}

# TXT Records
resource "hcloud_dns_record" "txt_onmicrosoft" {
  zone_id = hcloud_dns_zone.main.id
  name    = "@"
  value   = "NETORGFT17671803.onmicrosoft.com"
  type    = "TXT"
  ttl     = 3600
}

resource "hcloud_dns_record" "txt_spf" {
  zone_id = hcloud_dns_zone.main.id
  name    = "@"
  value   = "v=spf1 include:secureserver.net -all"
  type    = "TXT"
  ttl     = 3600
}

# SRV Records
resource "hcloud_dns_record" "srv_sip_tls" {
  zone_id = hcloud_dns_zone.main.id
  name    = "_sip._tls"
  value   = "100 1 443 sipdir.online.lync.com."
  type    = "SRV"
  ttl     = 3600
}

resource "hcloud_dns_record" "srv_sipfederationtls" {
  zone_id = hcloud_dns_zone.main.id
  name    = "_sipfederationtls._tcp"
  value   = "100 1 5061 sipfed.online.lync.com."
  type    = "SRV"
  ttl     = 3600
}

# Output the nameservers for reference
output "hetzner_nameservers" {
  value = [
    "helium.ns.hetzner.de",
    "oxygen.ns.hetzner.de", 
    "hydrogen.ns.hetzner.de"
  ]
  description = "Update your domain registrar with these nameservers"
}