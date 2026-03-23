output "alb_dns_name" {
  value = module.alb.dns_name
}

output "demo_url" {
  value = "https://${local.fqdn}"
}
