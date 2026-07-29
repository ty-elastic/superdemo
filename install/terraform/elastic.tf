
module "es_serverless" {
  source = "./modules/serverless" # Relative path to your module

  # Pass required variables into the module
  project = var.labels.project
  region = "gcp-${var.region}"
  cloud_apikey = var.es_cloud_apikey
  cluster_name = var.cluster_name
  enable = var.es_cluster_type == "serverless" ? true : false
}

module "es_hosted" {
  source = "./modules/hosted" # Relative path to your module

  # Pass required variables into the module
  project = var.labels.project
  region = "gcp-us-west2"
  cloud_apikey = var.es_cloud_apikey
  cluster_name = var.cluster_name
  enable = var.es_cluster_type == "hosted" ? true : false
}

locals {
  # Uses the variable if provided; otherwise falls back to the previous step's output
  elasticsearch_url = coalesce(var.elasticsearch_url, module.es_hosted.elasticsearch_url, module.es_serverless.elasticsearch_url)
  kibana_url = coalesce(var.kibana_url,  module.es_hosted.kibana_url,  module.es_serverless.kibana_url)
  ingest_url = coalesce(var.ingest_url, module.es_hosted.ingest_url, module.es_serverless.ingest_url)
  fleet_url = coalesce(var.fleet_url, module.es_hosted.fleet_url, module.es_serverless.fleet_url)
  elasticsearch_username = coalesce(var.elasticsearch_apikey, module.es_hosted.elasticsearch_username, module.es_serverless.elasticsearch_username)
  elasticsearch_password = coalesce(var.elasticsearch_apikey, module.es_hosted.elasticsearch_password, module.es_serverless.elasticsearch_password)
}

resource "time_sleep" "wait" {
  count = var.es_cluster_type != "" ? 1 : 0
  depends_on      = [local.elasticsearch_url]

  create_duration = "1m"
}

provider "elasticstack" {
  elasticsearch {
    username  = local.elasticsearch_username
    password  = local.elasticsearch_password
    endpoints = [local.elasticsearch_url]
  }
}

resource "elasticstack_elasticsearch_security_api_key" "project_api_key" {
  count = var.es_cluster_type != "" ? 1 : 0
  depends_on    = [time_sleep.wait]

  name = "superdemo"
}

locals {
  elasticsearch_apikey = elasticstack_elasticsearch_security_api_key.project_api_key[0].encoded
}
