# SuperDemo

A unified application and Elasticsearch environment for showcasing Elasticsearch Observability features.

# Deployment Models

## k8s app cluster and Elastic Cluster

### Requirements

* terraform
* gcloud cli and suitable Google Cloud account

### Environment

Create a `terraform.tfvars` file in the `install/terraform` folder with the following variables filled in:

```
project = "<req>"
region  = "<req>"
zone    = "<req>"

es_cloud_apikey = "<req>"
es_cluster_type = "serverless" # or "hosted"

labels = {
  division   = "<req>"
  org        = "<req>"
  team       = "<req>"
  project    = "<req>"
  keep-until = "<req>"
}
```

### Install using terraform

```
cd terraform
terraform init -upgrade
terraform apply
```

### Retrieve app credentials

```
terraform output -json traefik_auth
```

## k8s app cluster (BYOC Elastic Cluster)

### Requirements

* terraform
* gcloud cli and suitable Google Cloud account

### Environment

Create a `terraform.tfvars` file in the `install/terraform` folder with the following variables filled in:

```
project = "<req>"
region  = "<req>"
zone    = "<req>"

elasticsearch_url    = "<req>"
elasticsearch_apikey = "<req>"
fleet_url            = "<req>"
kibana_url           = "<req>"
ingest_url           = "<req>" # this needs to have a port (:443) at the end

es_cluster_type = "" # leave blank

labels = {
  division   = ""
  org        = ""
  team       = ""
  project    = ""
  keep-until = ""
}
```

### Install using terraform

```
cd terraform
terraform init -upgrade
terraform apply
```

### Retrieve app credentials

```
terraform output -json traefik_auth
```

## BYO k8s cluster

### Requirements

* kubectl

### Environment

Put the following env vars into a `.env` file

```
ELASTICSEARCH_URL=""
ELASTICSEARCH_APIKEY=""
FLEET_URL=""
KIBANA_URL=""
INGEST_URL="" # this needs to have a port (:443) at the end
```

### Install using in-cluster k8s job

Make sure your active k8s context is pointed to your k8s cluster and that you have a `.env` file with the aforementioned environment variables.

`./install.sh`

Wait for job to complete (~15 minutes)
