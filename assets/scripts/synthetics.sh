#!/bin/bash

source $PWD/assets/scripts/retry.sh

OPTIND=1
while getopts "n:h:i:j:k:t:" opt
do
   case "$opt" in
      n ) namespace="$OPTARG" ;;

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;
      t ) elasticsearch_fleet_endpoint="$OPTARG" ;;
   esac
done

export AGENT_VERSION=9.4.3

####################################################################### CREATE POLICY
POLICY_NUM=0

create_synthetics_policy() {
  printf "$FUNCNAME...\n"

  ((POLICY_NUM++))

  output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/fleet/agent_policies?sys_monitoring=false" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{
    "name": "Synthetics '$POLICY_NUM'",
    "description": "",
    "namespace": "default",
    "monitoring_enabled": [
      "metrics"
    ]
  }')

  http_code=$(echo "$output" | tail -n1)
  http_response=$(echo "$output" | sed '$d')
  if [ "$http_code" != "200" ]; then
    printf "$FUNCNAME...ERROR $http_code: $output\n"
    return 1
  fi

    POLICY_ID=$(echo $http_response | jq -r '.item.id')

    if [[ -z "$POLICY_ID" ]]; then
        printf "$FUNCNAME...ERROR: POLICY_ID is unset\n"
        return 1
    fi
    printf "$FUNCNAME...POLICY_ID=$POLICY_ID\n"

    printf "$FUNCNAME...SUCCESS\n"
    return 0
}
retry_command_lin create_synthetics_policy

config_synthetics_agent() {
    printf "$FUNCNAME...\n"

    output=$(curl -s -X GET "$elasticsearch_kibana_endpoint/api/fleet/enrollment_api_keys" \
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

    ENROLLMENT=$(echo $http_response | jq -r '.items[] | select (.policy_id == "'$POLICY_ID'")')

    ENROLLMENT_ID=$(echo $ENROLLMENT | jq -r '.id')
    ENROLLMENT_API_KEY_ID=$(echo $ENROLLMENT | jq -r '.api_key_id')
    export ENROLLMENT_API_KEY=$(echo $ENROLLMENT | jq -r '.api_key')

    if [[ -z "$ENROLLMENT_API_KEY" ]]; then
        printf "$FUNCNAME...ERROR: ENROLLMENT_API_KEY is unset\n"
        return 1
    fi

    printf "$FUNCNAME...ENROLLMENT_API_KEY=$ENROLLMENT_API_KEY\n"

    export FLEET_URL=$elasticsearch_fleet_endpoint
    envsubst < agents/synthetics/synthetics.yaml | kubectl apply -f -
    printf "$FUNCNAME...SUCCESS\n"
}
config_synthetics_agent

# ------------- CREATE PRIVATE MONITOR

config_synthetics_private_location() {
  printf "$FUNCNAME...\n"

  output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/synthetics/private_locations" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{
    "label": "host-1",
    "agentPolicyId": "'$POLICY_ID'",
    "geo": {
      "lat": 0,
      "lon": 0
    },
    "spaces": [
      "default"
    ]
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
config_synthetics_private_location
