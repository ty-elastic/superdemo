#!/bin/bash

source $PWD/assets/scripts/retry.sh

OPTIND=1
while getopts "h:i:" opt
do
   case "$opt" in
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
   esac
done

config_spaces() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X PUT "$elasticsearch_kibana_endpoint/api/spaces/space/default" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"id": "default", "name": "Default", "solution": "oblt"}')

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
config_spaces

hide_announcements() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/kibana/global_settings" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"changes":{"hideAnnouncements":true}}')

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
hide_announcements





# cat <<EOF >> rbac.json
# {
#   "cluster": [],
#   "indices": [
#     {
#       "names": [
#         "logs-proxy.otel-default"
#       ],
#       "privileges": [
#         "read",
#         "view_index_metadata"
#       ],
#       "field_security": {
#         "grant": [
#           "*"
#         ],
#         "except": [
#           "attributes.client.ip","body.text"
#         ]
#       },
#       "allow_restricted_indices": false
#     },
#     {
#       "names": [
#         ".slo-observability.*"
#       ],
#       "privileges": [
#         "read",
#         "view_index_metadata"
#       ],
#       "allow_restricted_indices": false
#     },
#     {
#       "names": [
#         ".siem-signals*",
#         ".lists-*",
#         ".items-*",
#         ".reindexed-v8-siem-signals*",
#         ".reindexed-v8-lists-*",
#         ".reindexed-v8-items-*"
#       ],
#       "privileges": [
#         "read",
#         "view_index_metadata"
#       ],
#       "allow_restricted_indices": false
#     },
#     {
#       "names": [
#         ".alerts*",
#         ".preview.alerts*",
#         ".adhoc.alerts*"
#       ],
#       "privileges": [
#         "read",
#         "view_index_metadata"
#       ],
#       "allow_restricted_indices": false
#     },
#     {
#       "names": [
#         "profiling-*",
#         ".profiling-*"
#       ],
#       "privileges": [
#         "read",
#         "view_index_metadata"
#       ],
#       "allow_restricted_indices": false
#     }
#   ],
#   "applications": [
#     {
#       "application": "kibana-.kibana",
#       "privileges": [
#         "read"
#       ],
#       "resources": [
#         "*"
#       ]
#     }
#   ],
#   "run_as": [],
#   "description": "Grants read-only access to all features in Kibana (including Solutions) and to data indices."
# }
# EOF

# curl -X POST "$ELASTICSEARCH_URL/_security/role/limited_viewer" \
#     --header 'Content-Type: application/json' \
#     --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
#     -d @rbac.json

# curl -X PUT "$ELASTICSEARCH_URL/_security/user/limited_user" \
#     --header 'Content-Type: application/json' \
#     --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
#     -d'
#     {
#         "password": "elastic",
#         "roles": [
#           "limited_viewer"
#         ],
#         "full_name": "",
#         "email": "",
#         "metadata": {},
#         "enabled": true
#     }'