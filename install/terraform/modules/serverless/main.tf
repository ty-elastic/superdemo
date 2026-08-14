provider "ec" {
  apikey = var.cloud_apikey
}

# provider "http-full" {
#   # Generally left empty unless initializing global properties
# }

# Create an Elastic Cloud Serverless Project
resource "ec_observability_project" "es_cluster" {
  count = var.enable == true ? 1 : 0

  name        = "${var.cluster_name}"
  region_id   = "gcp-${var.region}"
  alias = "${var.cluster_name}"
}

resource "time_sleep" "wait" {
  count = var.enable == true ? 1 : 0
  depends_on      = [ec_observability_project.es_cluster]

  create_duration = "1m"
}

# 1. Execute the REST API Call
data "http" "get_fleet_endpoint" {
  count = var.enable == true ? 1 : 0
  depends_on    = [time_sleep.wait]

  url    = "${ec_observability_project.es_cluster[0].endpoints.kibana}/api/fleet/fleet_server_hosts"
  method = "GET"

  request_headers = {
    Accept        = "application/json"
    Authorization = "Basic ${base64encode("${ec_observability_project.es_cluster[0].credentials.username}:${ec_observability_project.es_cluster[0].credentials.password}")}"
  }

  # Configure the retry behavior
  retry {
    attempts     = 5
    min_delay_ms = 5000
    max_delay_ms = 5000
  }
}

data "http" "turn_on_o11y" {
  count = var.enable == true ? 1 : 0
  provider = http-full

  url    = "https://cloud.elastic.co/api/v1/serverless/projects/observability/${ec_observability_project.es_cluster[0].id}"
  method = "PATCH"

  request_headers = {
    Accept        = "application/json"
    Content-Type = "application/json"
    Authorization = "ApiKey ${var.cloud_apikey}"
  }

  request_body = jsonencode({
    monitoring = {
      logging = {
        audit = {
          destination = {
            project_id = "${ec_observability_project.es_cluster[0].id}"
            project_type = "observability"
          }
          enabled = true
          ignore_filters = []
        }
      }
    }
  })
}

locals {
  # Convert raw response body into a Terraform map/object
  get_fleet_endpoint = try(jsondecode(data.http.get_fleet_endpoint[0].response_body), null)

  # 2. Filter the array to find the entry where name is "dev-db"
  fleet_endpoint_block = try(one([
    for item in local.get_fleet_endpoint.items : item 
    if item.id == "default-fleet-server"
  ]), null)

  # Extract specific values using standard dot notation
  fleet_url   = try(local.fleet_endpoint_block.host_urls[0], null)
}
