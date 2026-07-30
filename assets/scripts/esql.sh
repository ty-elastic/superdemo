#!/bin/bash

source $PWD/assets/scripts/retry.sh

OPTIND=1
while getopts "h:i:j:" opt
do
   case "$opt" in
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
   esac
done

config_esql_df_source() {
   printf "$FUNCNAME $1...\n"

   output=$(curl -s -X PUT "$elasticsearch_kibana_endpoint/internal/data_federation/data_sources/$1" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"description":"'$1'","settings":{"region":"'$3'","auth":"anonymous"},"type":"'$2'"}')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   printf "$FUNCNAME $1...SUCCESS\n"
   return 0
}
config_esql_df_source logs s3 eu-west-3

config_esql_df_set() {
   printf "$FUNCNAME $1...\n"

   output=$(curl -s -X PUT "$elasticsearch_kibana_endpoint/internal/data_federation/dataset/$1" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"data_source":"'$2'","resource":"'$3'","settings":{"format":"'$4'"}}')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   printf "$FUNCNAME $1...SUCCESS\n"
   return 0
}
config_esql_df_set cloudflare_logs logs s3://datasets-documentation/clickstack-integrations/cloudflare/cloudflare-http-logs.json ndjson


