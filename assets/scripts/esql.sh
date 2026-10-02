#!/bin/bash

source $PWD/assets/scripts/retry.sh

OPTIND=1
while getopts "i:j:" opt
do
   case "$opt" in
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
   esac
done

config_geodatabase() {
    printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_es_endpoint/_query" \
        -H 'Content-Type: application/json' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}" \
        -d '{
            "query": "ROW client_ip = \"107.80.38.59\" | IP_LOCATION geo = client_ip"
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
config_geodatabase
