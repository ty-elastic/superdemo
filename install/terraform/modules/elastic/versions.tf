terraform {
  required_version = ">= 1.5.0"

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.16.3"
    }
  }
}
