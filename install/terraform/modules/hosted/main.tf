provider "ec" {
  apikey = var.cloud_apikey
}

resource "ec_deployment" "es_cluster" {
  count = var.enable == true ? 1 : 0

  name                   = "${var.cluster_name}-${var.project}"
  region                 = "${var.region}"
  version                = "${var.es_version}"
  deployment_template_id = "${var.deployment_template_id}"
  alias = "${var.cluster_name}-${var.project}"

  elasticsearch = {
    hot = {
      size          = "4g"
      size_resource = "memory"
      zone_count    = 1
      autoscaling = {}
    }
    ml = {
      size          = "4g"
      size_resource = "memory"
      zone_count    = 2
      autoscaling = {}
    }
    autoscale = false
    config = {
      user_settings_yaml = <<-EOT
        esql.federation.enabled: true
      EOT
    }
  }

  kibana = {
      size          = "2g"
      size_resource = "memory"
      zone_count    = 1   
      config = {
      user_settings_yaml = <<-EOT
        xpack.dataFederation.enabled: true
      EOT
    }
  }

  integrations_server = {
      size          = "1g"
      size_resource = "memory"
      zone_count    = 1   
  }
}
