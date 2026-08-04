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

config_streams_sigevents() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/kibana/settings" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"changes":{"observability:streamsEnableSignificantEvents":true}}')

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
config_streams_sigevents

# config_ns() {
#    printf "$FUNCNAME...\n"

#    output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/kibana/settings" \
#       -w "\n%{http_code}" \
#       -H 'kbn-xsrf: true' \
#       -H 'x-elastic-internal-origin: Kibana' \
#       -H "Authorization: ApiKey ${elasticsearch_api_key}" \
#       -H 'Content-Type: application/json' \
#       -d '{"changes":{"feature_flags.overrides":{"streams.significantEventsAvailable": true}}}')

#    # Extract HTTP status code
#    http_code=$(echo "$output" | tail -n1)
#    http_response=$(echo "$output" | sed '$d')
#    if [ "$http_code" != "200" ]; then
#       printf "$FUNCNAME...ERROR $http_code: $http_response\n"
#       return 1
#    fi
#    printf "$FUNCNAME...SUCCESS\n"
#    return 0
# }
# config_ns

config_logsources() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/kibana/settings" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"changes":{"observability:logSources":["logs.*", "logs-*-*", "logs-*", "filebeat-*"]}}')

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
config_logsources

config_streams_wired() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/streams/_enable" \
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
   printf "$FUNCNAME...SUCCESS\n"
   return 0
}
config_streams_wired
