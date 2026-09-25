

output "elasticsearch_url" {
  value       = local.elasticsearch_url
}

output "kibana_url" {
  value       = local.kibana_url
}

output "ingest_url" {
  value       = local.ingest_url
}

output "fleet_url" {
  value       = local.fleet_url
}

output "elasticsearch_username" {
  value     = local.elasticsearch_username
  sensitive = true
}

output "elasticsearch_password" {
  value     = local.elasticsearch_password
  sensitive = true
}

output "elasticsearch_apikey" {
  value     = local.elasticsearch_apikey
  sensitive = true
}
