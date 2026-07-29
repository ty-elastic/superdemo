output "elasticsearch_url" {
  value       = try(ec_observability_project.es_cluster[0].endpoints.elasticsearch, null)
}

output "kibana_url" {
  value       = try(ec_observability_project.es_cluster[0].endpoints.kibana, null)
}

output "ingest_url" {
  value       = try(ec_observability_project.es_cluster[0].endpoints.ingest, null)
}

output "fleet_url" {
  value       = length(ec_observability_project.es_cluster) > 0 ? local.fleet_url : null
}

output "elasticsearch_username" {
  value     = try(ec_observability_project.es_cluster[0].credentials.username, null)
  sensitive = true
}

output "elasticsearch_password" {
  value     = try(ec_observability_project.es_cluster[0].credentials.password, null)
  sensitive = true
}
