provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

locals {
  course = {
    test = "o11y--course--field--100-e2e--test"
    prod = "o11y--course--field--100-e2e--serverless"
  }
  # Fallback to a default if the variable doesn't match a known key
  selected_course = try(
    local.course[var.environment], 
    local.course["prod"]
  )

  install_image = "us-central1-docker.pkg.dev/elastic-sa/tbekiares/install:${local.selected_course}"

  # String interpolation combining both variables
  cluster_name = "${var.cluster_name}-${var.labels.project}"
}

resource "random_bytes" "access_password" {
  length = 12
}

# Windows username: "win" prefix + 8 lowercase letters (max 20 chars, no special chars)
resource "random_string" "windows_username" {
  length  = 11
  upper   = false
  numeric = false
  special = false
}

# Windows password: 24 alphanumeric chars, meets complexity (upper + lower + numeric = 3 categories)
resource "random_password" "windows_password" {
  length      = 24
  upper       = true
  lower       = true
  numeric     = true
  special     = false
  min_upper   = 4
  min_lower   = 4
  min_numeric = 4
}

resource "google_container_cluster" "primary" {
  name     = local.cluster_name
  location = var.zone

  release_channel {
    channel = "REGULAR"
  }

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  # Constrain the pod/service ranges. Without this, GKE auto-allocates a full
  # /14 pod block per cluster from the default network's 10.0.0.0/9, which
  # caps the project at ~32 concurrent demo clusters and exhausts the VPC. A
  # /20 (4096 pod IPs) is ample for a 1-node demo cluster.
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/20"
    services_ipv4_cidr_block = "/24"
  }

  resource_labels = var.labels
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${local.cluster_name}-pool"
  cluster    = google_container_cluster.primary.id
  location   = var.zone
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    image_type   = "COS_CONTAINERD"
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb

    metadata = {
      disable-legacy-endpoints = "true"
    }

    shielded_instance_config {
      enable_secure_boot          = false
      enable_integrity_monitoring = true
    }

    labels = var.labels
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

resource "kubernetes_service_account_v1" "install" {
  metadata {
    name      = "${var.job_name}-sa"
    namespace = var.job_namespace
  }
}

resource "kubernetes_cluster_role_binding_v1" "install" {
  metadata {
    name = "${var.job_name}-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin" # Use a more restrictive role in production
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.install.metadata[0].name
    namespace = var.job_namespace
  }
}

resource "kubernetes_job_v1" "install" {
  metadata {
    name      = var.job_name
    namespace = var.job_namespace
  }

  spec {
    backoff_limit = var.job_backoff_limit

    template {
      metadata {
        labels = {
          app = var.job_name
        }
      }

      spec {
        restart_policy       = "Never"
        service_account_name = kubernetes_service_account_v1.install.metadata[0].name

        container {
          name  = "install"
          image = local.install_image

          env {
            name  = "COURSE"
            value = local.selected_course
          }
          env {
            name  = "ELASTICSEARCH_URL"
            value = local.elasticsearch_url
          }
          env {
            name  = "ELASTICSEARCH_APIKEY"
            value = local.elasticsearch_apikey
          }
          env {
            name  = "ACCESS_PASSWORD"
            value = random_bytes.access_password.base64
          }
          env {
            name  = "FLEET_URL"
            value = local.fleet_url
          }
          env {
            name  = "KIBANA_URL"
            value = local.kibana_url
          }
          env {
            name  = "INGEST_URL"
            value = local.ingest_url
          }
          env {
            name  = "WINDOWS_HOST_IP"
            value = google_compute_instance.windows_server.network_interface[0].network_ip
          }
          env {
            name  = "WINDOWS_HOST_USERNAME"
            value = random_string.windows_username.result
          }
          env {
            name  = "WINDOWS_HOST_PASSWORD"
            value = random_password.windows_password.result
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = var.job_timeout
  }

  depends_on = [
    google_container_node_pool.primary_nodes,
    google_compute_instance.windows_server,
    google_compute_firewall.windows_ingress_from_pods,
    google_compute_firewall.windows_egress_internet
  ]
}

locals {
  windows_startup_auth = <<-EOT
      $username = '${random_string.windows_username.result}'
      $password = '${random_password.windows_password.result}'
      $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
      if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $username -Password $securePassword -PasswordNeverExpires
        Add-LocalGroupMember -Group "Administrators" -Member $username
      }

      Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
      Start-Service sshd
      Set-Service -Name sshd -StartupType 'Automatic'
    EOT
}

resource "google_compute_instance" "windows_server" {
  name         = "${local.cluster_name}-windows"
  machine_type = "n2-standard-4"
  zone         = var.zone

  tags = ["windows-rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"

    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    windows-startup-script-ps1 = local.windows_startup_auth
  }

  labels = var.labels

  timeouts {
    create = var.job_timeout
  }
}

# Allow ingress to the Windows VM from k8s pods only (any port/protocol)
resource "google_compute_firewall" "windows_ingress_from_pods" {
  name    = "${local.cluster_name}-windows-ingress-pods"
  network = "default"

  allow {
    protocol = "all"
  }

  source_ranges = [google_container_cluster.primary.cluster_ipv4_cidr]
  target_tags   = ["windows-rdp"]
}

# Allow full egress from the Windows VM to the internet
resource "google_compute_firewall" "windows_egress_internet" {
  name      = "${local.cluster_name}-windows-egress-internet"
  network   = "default"
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["windows-rdp"]
}
