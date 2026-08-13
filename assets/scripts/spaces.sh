#!/bin/bash

source $PWD/assets/scripts/retry.sh

elasticsearch_limited_password=limited_user

OPTIND=1
while getopts "h:i:j:8:" opt
do
   case "$opt" in
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      8 ) elasticsearch_limited_password="$OPTARG" ;;
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

create_space() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/spaces/space" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"id": "limited_viewer", "name": "Limited Viewer", "solution": "oblt"}')

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
create_space

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

cat <<EOF >> rbac.json
{
  "cluster": [
    "monitor_inference"
  ],
  "indices": [
    {
      "names": [
        "/~(([.]|ilm-history-).*)/"
      ],
      "privileges": [
        "read",
        "view_index_metadata"
      ],
      "allow_restricted_indices": false,
      "field_security": {
        "grant": [
          "*"
        ],
        "except": [
          "attributes.com.example.customer_id"
        ]
      }
    },
    {
      "names": [
        ".slo-observability.*"
      ],
      "privileges": [
        "read",
        "view_index_metadata"
      ],
      "allow_restricted_indices": false
    },
    {
      "names": [
        ".evaluation-*"
      ],
      "privileges": [
        "read",
        "view_index_metadata"
      ],
      "allow_restricted_indices": false
    },
    {
      "names": [
        ".siem-signals*",
        ".lists-*",
        ".items-*",
        ".reindexed-v8-siem-signals*",
        ".reindexed-v8-lists-*",
        ".reindexed-v8-items-*",
        ".entities.v1.latest.security_*",
        ".entities.v2.latest.security_*",
        ".entities.v2.updates.security_*",
        ".entities.v2.metadata.security_*",
        ".asset-criticality.asset-criticality-*",
        ".entity_analytics.monitoring*",
        ".entity_analytics.entity-leads*",
        ".entity_analytics.watchlists.*",
        ".entities.*.history.*"
      ],
      "privileges": [
        "read",
        "view_index_metadata"
      ],
      "allow_restricted_indices": false
    },
    {
      "names": [
        ".alerts*",
        ".preview.alerts*",
        ".adhoc.alerts*"
      ],
      "privileges": [
        "read",
        "view_index_metadata"
      ],
      "allow_restricted_indices": false
    },
    {
      "names": [
        "profiling-*",
        ".profiling-*"
      ],
      "privileges": [
        "read",
        "view_index_metadata"
      ],
      "allow_restricted_indices": false
    }
  ],
  "applications": [
    {
      "application": "kibana-.kibana",
      "privileges": [
        "feature_discover_v2.read",
        "feature_dashboard_v2.read",
        "feature_maps_v2.read",
        "feature_ml.read",
        "feature_visualize_v2.read",
        "feature_workflowsManagement.read",
        "feature_alerting_v2_rules.read",
        "feature_alerting_v2_alerts.read",
        "feature_alerting_v2_action_policies.read",
        "feature_alerting_v2_execution_history.read",
        "feature_logs.read",
        "feature_infrastructure.read",
        "feature_apm.read",
        "feature_uptime.read",
        "feature_observabilityCasesV3.read",
        "feature_slo.read",
        "feature_observabilityAlerts.read",
        "feature_observabilityAIAssistant.all",
        "feature_profiling.read"
      ],
      "resources": [
        "space:limited_viewer"
      ]
    }
  ],
  "run_as": [],
  "description": "Grants read-only access to all features in Kibana (including Solutions) and to data indices."
}
EOF

curl -X POST "$elasticsearch_es_endpoint/_security/role/limited_viewer" \
    --header 'Content-Type: application/json' \
    --header "Authorization: ApiKey ${elasticsearch_api_key}" \
    -d @rbac.json

curl -X PUT "$elasticsearch_es_endpoint/_security/user/limited_user" \
    --header 'Content-Type: application/json' \
    --header "Authorization: ApiKey ${elasticsearch_api_key}" \
    -d'
    {
        "password": "'"$elasticsearch_limited_password"'",
        "roles": [
          "limited_viewer"
        ],
        "full_name": "",
        "email": "",
        "metadata": {},
        "enabled": true
    }'