
root="../../"
export repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
export course=latest

OPTIND=1
while getopts "s:c:r:i:j:h:" opt
do
   case "$opt" in
      s ) root="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      r ) repo="$OPTARG" ;;

      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
   esac
done

source $root/assets/scripts/retry.sh

helm repo add requarks https://charts.js.wiki
kubectl create namespace wiki
helm install wiki \
    --namespace wiki \
    --set ingress.enabled=false \
    --set postgresql.persistence.enabled=false \
    --set postgresql.image.repository=$repo/postgresql \
    --set postgresql.image.tag=$course \
    --set postgresql.image.pullPolicy=Always \
    requarks/wiki

retry_command_lin check_http_ok "http://wiki.wiki.svc.cluster.local:80/"

envsubst '$course,$repo' < $root/utils/wiki.js/install/wikijs.yaml | kubectl apply -f -

# wait
kubectl wait --for=condition=complete job/wikijs-config -n wiki --timeout=5m

create_wiki_connector() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_es_endpoint/_connector" \
         -w "\n%{http_code}" \
         -H "Authorization: ApiKey ${elasticsearch_api_key}" \
         -H 'Content-Type: application/json' \
         -d '{"description":"wiki content","index_name":"wiki","is_native":false,"name":"wiki","service_type":"postgresql"}')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   #echo $http_code
   http_response=$(echo "$output" | sed '$d')
   if [[ "$http_code" != "201" && "$http_code" != "400" ]]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi

   if [ "$http_code" = "400" ]; then
      output=$(curl -s -X GET "$elasticsearch_es_endpoint/_connector" \
            -w "\n%{http_code}" \
            -H "Authorization: ApiKey ${elasticsearch_api_key}" \
            -H 'Content-Type: application/json')
      http_code=$(echo "$output" | tail -n1)
      http_response=$(echo "$output" | sed '$d')
      CONNECTOR=$(echo $http_response | jq -r '.results[] | select (.name == "wiki")')
      CONNECTOR_ID=$(echo $CONNECTOR | jq -r '.id')
      printf $CONNECTOR_ID
   else
      CONNECTOR_ID=$(echo $http_response | jq -r '.id')
   fi

   printf "$FUNCNAME...SUCCESS id=$CONNECTOR_ID\n"
   return 0
}
retry_command_lin create_wiki_connector

export CONNECTOR_ID=$CONNECTOR_ID
export elasticsearch_es_endpoint=$elasticsearch_es_endpoint
export elasticsearch_api_key=$elasticsearch_api_key
envsubst '$elasticsearch_es_endpoint,$elasticsearch_api_key,$CONNECTOR_ID' < $root/utils/wiki.js/install/connector.yaml | kubectl apply -f -
kubectl -n wiki rollout restart deployment/connector

set_mapping() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X PUT "$elasticsearch_es_endpoint/wiki" \
         -w "\n%{http_code}" \
         -H "Authorization: ApiKey ${elasticsearch_api_key}" \
         -H 'Content-Type: application/json' \
         -d '{"mappings": {"dynamic":false,"properties":{"_timestamp":{"type":"date"},"database":{"type":"keyword"},"id":{"type":"keyword"},"schema":{"type":"keyword"},"table":{"type":"keyword"},"public_pages_content":{"type":"semantic_text"},"public_pages_description":{"type":"semantic_text"},"public_pages_title":{"type":"semantic_text"},"public_pages_creatorid":{"type":"long"},"public_pages_id":{"type":"long"},"public_pages_path":{"type":"keyword"}}}}')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [[ "$http_code" != "200" && "$http_code" != "400" ]]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi

   printf "$FUNCNAME...SUCCESS\n"
   return 0
}
retry_command_lin set_mapping

create_wiki_config() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X PUT "$elasticsearch_es_endpoint/_connector/$CONNECTOR_ID/_configuration" \
         -w "\n%{http_code}" \
         -H "Authorization: ApiKey ${elasticsearch_api_key}" \
         -H 'Content-Type: application/json' \
         -d '{"values": {"host":"wiki-postgresql","port":5432,"username":"postgres","password":"postgres","database":"wiki","schema":"public","tables":"pages","ssl_enabled":false}}')

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
retry_command_lin create_wiki_config

sync() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_es_endpoint/_connector/_sync_job" \
         -w "\n%{http_code}" \
         -H "Authorization: ApiKey ${elasticsearch_api_key}" \
         -H 'Content-Type: application/json' \
         -d '{"id": "'$CONNECTOR_ID'", "job_type": "full"}')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [ "$http_code" != "201" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi

   printf "$FUNCNAME...SUCCESS\n"
   return 0
}
retry_command_lin sync
