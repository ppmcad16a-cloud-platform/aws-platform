output "ingress_ip" {
  value = local.cluster_outputs.ingress_ip
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}
