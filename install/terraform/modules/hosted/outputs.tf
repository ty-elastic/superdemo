output "elasticsearch_url" {
  value       = try(ec_deployment.es_cluster[0].elasticsearch.https_endpoint, null)
}

output "kibana_url" {
  value       = try(ec_deployment.es_cluster[0].kibana.https_endpoint, null)
}

output "ingest_url" {
  value       = length(ec_deployment.es_cluster) > 0 ? "https://${var.alias}.ingest.${var.region}.gcp.elastic-cloud.com" : null
}

output "fleet_url" {
  value       = length(ec_deployment.es_cluster) > 0 ? "https://${var.alias}.fleet.${var.region}.gcp.elastic-cloud.com" : null
}

output "elasticsearch_username" {
  value     = try(ec_deployment.es_cluster[0].elasticsearch_username, null)
  sensitive = true
}

output "elasticsearch_password" {
  value     = try(ec_deployment.es_cluster[0].elasticsearch_password, null)
  sensitive = true
}
