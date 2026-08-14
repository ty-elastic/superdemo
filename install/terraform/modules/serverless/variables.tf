variable "region" {
  description = "GCP region (used for provider defaults)"
  type        = string
}

variable "enable" {
  type = bool
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "cloud_apikey" {
  description = "Elastic cloud apikey for creating elastic cloud projects"
  type        = string
}
