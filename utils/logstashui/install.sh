
root="../../"
export course=latest
export repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
export course=latest

OPTIND=1
while getopts "s:c:r:i:j:h:" opt
do
   case "$opt" in
      s ) root="$OPTARG" ;;
      r ) repo="$OPTARG" ;;

      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
   esac
done

export elasticsearch_es_endpoint=$elasticsearch_es_endpoint
export elasticsearch_api_key=$elasticsearch_api_key
envsubst '$course,$repo,$elasticsearch_api_key,$elasticsearch_es_endpoint' < $root/utils/logstashui/logstashui.yaml | kubectl apply -f -
