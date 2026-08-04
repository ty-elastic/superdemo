#!/bin/bash

source $PWD/assets/scripts/retry.sh

OPTIND=1
while getopts "n:h:i:j:k:" opt
do
   case "$opt" in
      n ) namespace="$OPTARG" ;;

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;
   esac
done

config_o11y_ai_assistant() {
   AI_CONNECTOR=".anthropic-claude-4.6-sonnet-chat_completion"

   printf "$FUNCNAME...\n"
   printf "$FUNCNAME...using connector: $AI_CONNECTOR\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/kibana/settings" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"changes":{"agentBuilder:tracing:enabled": true, "genAiSettings:tokenUsageTracking": true, "aiAssistant:preferredChatExperience": "agent", "agentBuilder:dashboardTools": true, "agentBuilder:experimentalFeatures": true, "genAiSettings:defaultAIConnector": "'$AI_CONNECTOR'"}}')

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
config_o11y_ai_assistant

config_tracing_dashboard() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/gen_ai_settings/agent_builder/tracing_dashboard" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"enabled":true}')

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
config_tracing_dashboard

config_o11y_ai_docs() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/product_doc_base/install" \
      -m 5 \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"inferenceId":".jina-embeddings-v5-text-small","resourceType":"product_doc"}')

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
config_o11y_ai_docs

