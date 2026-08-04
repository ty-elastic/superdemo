#!/bin/bash

source $PWD/assets/scripts/retry.sh

k3s=false

OPTIND=1
while getopts "h:i:j:k:f:o:t:9:" opt
do
   case "$opt" in
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;
      t ) elasticsearch_fleet_endpoint="$OPTARG" ;;

      f ) force="$OPTARG" ;;
      o ) deploy_otel="$OPTARG" ;;

      9 ) k3s="$OPTARG" ;;
   esac
done

if [[ ! "$elasticsearch_otlp_endpoint" =~ :[0-9]+($|/) ]]; then
    elasticsearch_otlp_endpoint=$elasticsearch_otlp_endpoint:443
    printf "appending port to ingest url: $elasticsearch_otlp_endpoint\n"
fi

export AGENT_VERSION=9.5.0

check_otel() {
    kubectl wait --for=condition=Ready pods --all -n opentelemetry-operator-system --timeout=5m

    if kubectl describe otelinst -n opentelemetry-operator-system | grep -q "No resources found"; then
        echo "otel operator not yet ready"
        return 1
    else
        echo "otel operator ready"
        return 0
    fi
}

create_opamp_policy() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/fleet/agent_policies" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{
            "name": "OpAMP",
            "id": "opamp",
            "namespace": "default",
            "description": "Agent policy for OpAMP collectors",
            "is_managed": true,
            "inactivity_timeout": 86400
    }')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   
   printf "$FUNCNAME...SUCCESS\n"
   return 0
}

get_opamp_apikey() {
    printf "$FUNCNAME for $1...\n"

    output=$(curl -s -X GET "$elasticsearch_kibana_endpoint/api/fleet/enrollment_api_keys?page=1&perPage=1&kuery=policy_id%3A%22opamp%22" \
        -w "\n%{http_code}" \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}")

    # Extract HTTP status code
    http_code=$(echo "$output" | tail -n1)
    http_response=$(echo "$output" | sed '$d')
    if [ "$http_code" != "200" ]; then
        printf "$FUNCNAME...ERROR $http_code: $http_response\n"
        return 1
    fi

    OPAMP_API_KEY=$(echo $http_response | jq -r '.items[0].api_key')
    if [[ -z "$OPAMP_API_KEY" ]]; then
        printf "$FUNCNAME...ERROR: OPAMP_API_KEY is unset\n"
        return 1
    fi

    printf "$FUNCNAME...OPAMP_API_KEY=$OPAMP_API_KEY\n"
    export OPAMP_API_KEY=$OPAMP_API_KEY
    return 0
}

deploy_otel() {
    echo "deploying $deploy_otel.yaml"

    helm repo add open-telemetry 'https://open-telemetry.github.io/opentelemetry-helm-charts' --force-update

    EXISTING=false
    if kubectl get namespace opentelemetry-operator-system >/dev/null 2>&1; then
        EXISTING=true
    fi

    kubectl create namespace opentelemetry-operator-system

    echo elasticsearch_fleet_endpoint=$elasticsearch_fleet_endpoint

    kubectl --namespace opentelemetry-operator-system delete secret generic elastic-secret-otel
    kubectl create secret generic elastic-secret-otel \
        --namespace opentelemetry-operator-system \
        --from-literal=elastic_otlp_endpoint="$elasticsearch_otlp_endpoint" \
        --from-literal=elastic_endpoint="$elasticsearch_es_endpoint" \
        --from-literal=elastic_fleet_endpoint="$elasticsearch_fleet_endpoint" \
        --from-literal=elastic_fleet_opamp_api_key="$OPAMP_API_KEY" \
        --from-literal=elastic_api_key="$elasticsearch_api_key"

    cd agents/apm

    if [ "$k3s" = "true" ]; then
        helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
            --namespace opentelemetry-operator-system \
            --values "$deploy_otel.yaml" \
            --version '0.12.4' \
            --set clusterName=superdemo
    else
        helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
            --namespace opentelemetry-operator-system \
            --values "$deploy_otel.yaml" \
            --version '0.12.4'
    fi
    cd ../..

    cd agents/tbs
    envsubst '$AGENT_VERSION' < tbs.yaml | kubectl apply -f -
    cd ../..

    if [ "$EXISTING" = "true" ]; then
        kubectl -n opentelemetry-operator-system rollout restart deployment
        kubectl -n opentelemetry-operator-system rollout restart statefulset
    fi
}

create_opamp_policy
retry_command_lin get_opamp_apikey

deploy_otel
retry_command_lin check_otel
