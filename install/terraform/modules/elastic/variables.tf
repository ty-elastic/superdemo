variable "es_cluster_region" {
  description = "GCP region (used for provider defaults)"
  type        = string
  default     = "us-central1"
}

variable "es_cloud_apikey" {
  type = string
  default     = ""
}

variable "es_cluster_name" {
  type = string
  default     = ""
}

variable "es_cluster_hosted_version" {
  type = string
  default = "9.5.1"
}

variable "es_cluster_type" {
  type = string
  default = "serverless"
}


variable "elasticsearch_url" {
  description = "Elasticsearch URL for the o11y e2e serverless project, passed to the install container as ELASTICSEARCH_URL"
  type        = string
  default = ""
}

variable "elasticsearch_apikey" {
  description = "Elasticsearch API key for the o11y e2e serverless project, passed to the install container as ELASTICSEARCH_APIKEY"
  type        = string
  sensitive   = true
  default = ""
}

variable "elasticsearch_username" {
  type        = string
  sensitive   = true
  default = ""
}

variable "elasticsearch_password" {
  type        = string
  sensitive   = true
  default = ""
}

variable "fleet_url" {
  description = "Fleet Server URL for the o11y e2e serverless project, passed to the install container as FLEET_URL"
  type        = string
  default = ""
}

variable "kibana_url" {
  description = "Kibana URL for the o11y e2e serverless project, passed to the install container as KIBANA_URL"
  type        = string
  default = ""
}

variable "ingest_url" {
  description = "Ingest URL for the o11y e2e serverless project, passed to the install container as INGEST_URL"
  type        = string
  default = ""
}
