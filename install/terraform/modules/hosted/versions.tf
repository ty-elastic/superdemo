terraform {
  required_version = ">= 1.5.0"

  required_providers {
    ec = {
      source  = "elastic/ec"
    }
  }
}