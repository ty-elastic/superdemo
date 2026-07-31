variable "project" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region (used for provider defaults)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone the (zonal) GKE cluster is created in"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "superdemo"
}

variable "machine_type" {
  description = "Machine type for cluster nodes"
  type        = string
  default     = "n2-standard-16"
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "disk_type" {
  description = "Node boot disk type"
  type        = string
  default     = "pd-balanced"
}

variable "disk_size_gb" {
  description = "Node boot disk size in GB"
  type        = number
  default     = 100
}

variable "labels" {
  description = "Labels applied to the cluster and its nodes"
  type        = map(string)
  default = {
    division   = ""
    org        = ""
    team       = ""
    project    = ""
    keep-until = ""
  }
}

variable "job_name" {
  description = "Name of the Kubernetes Job"
  type        = string
  default     = "superdemo-install"
}

variable "job_namespace" {
  description = "Namespace to run the Job in"
  type        = string
  default     = "default"
}

variable "environment" {
  description = "test, prod"
  type        = string
  default     = "prod"
}

variable "job_backoff_limit" {
  description = "Number of retries before the Job is marked failed"
  type        = number
  default     = 0
}

variable "job_timeout" {
  description = "How long Terraform waits for the install Job to complete"
  type        = string
  default     = "45m"
}

variable "es_cloud_apikey" {
  type = string
}

variable "es_cluster_hosted_version" {
  type = string
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
