
root="../../"
export course=latest
export repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares

OPTIND=1
while getopts "s:c:r:i:j:h:" opt
do
   case "$opt" in
      s ) root="$OPTARG" ;;
      r ) repo="$OPTARG" ;;
      c ) course="$OPTARG" ;;

      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
   esac
done

echo $elasticsearch_api_key


export elasticsearch_api_key=$elasticsearch_api_key
export elasticsearch_es_endpoint=$elasticsearch_es_endpoint
export elasticsearch_kibana_endpoint=$elasticsearch_kibana_endpoint
envsubst '$course,$repo,$elasticsearch_api_key,$elasticsearch_es_endpoint,$elasticsearch_kibana_endpoint' < $root/utils/logstashui/logstashui.yaml | kubectl apply -f -
