#!/bin/bash

source $PWD/assets/scripts/retry.sh

namespace=na
elasticsearch_limited_password=limited_user

OPTIND=1
while getopts "n:h:i:j:k:8:" opt
do
   case "$opt" in
      n ) namespace="$OPTARG" ;;

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;
      8 ) elasticsearch_limited_password="$OPTARG" ;;
   esac
done

source $PWD/assets/scripts/spaces.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -8 $elasticsearch_limited_password
source $PWD/assets/scripts/genai.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
source $PWD/assets/scripts/streams.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
source $PWD/assets/scripts/workflow.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
