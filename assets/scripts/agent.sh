#!/bin/bash

source $PWD/assets/scripts/retry.sh

OPTIND=1
while getopts "h:i:j:n:" opt
do
   case "$opt" in
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      n ) elasticsearch_fleet_endpoint="$OPTARG" ;;
   esac
done

export AGENT_VERSION=9.5.0

####################################################################### CREATE POLICY
POLICY_NUM=0

create_linux_agent_policy() {
  printf "$FUNCNAME...\n"

  ((POLICY_NUM++))

  output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/fleet/agent_policies?sys_monitoring=true" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{
    "name": "Linux '$POLICY_NUM'",
    "description": "",
    "namespace": "default",
    "monitoring_enabled": [
      "logs",
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
retry_command_lin create_linux_agent_policy

config_linux_agent() {
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

    #envsubst < agents/synthetics/synthetics.yaml | kubectl apply -f -

    cd /root/
    curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-$AGENT_VERSION-linux-x86_64.tar.gz 
    tar xzvf elastic-agent-$AGENT_VERSION-linux-x86_64.tar.gz
    cd elastic-agent-$AGENT_VERSION-linux-x86_64
    ./elastic-agent install --non-interactive --url=$elasticsearch_fleet_endpoint --enrollment-token=$ENROLLMENT_API_KEY

    printf "$FUNCNAME...SUCCESS\n"
}
config_linux_agent
