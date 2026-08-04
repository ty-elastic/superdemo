#!/bin/bash

if [ -f ".env" ]; then
    set -o allexport # Automatically export all variables defined after this point
    source .env
    set +o allexport # Stop automatic exporting
fi

# es bootstrap
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -8 $ACCESS_PASSWORD -k $INGEST_URL -t $FLEET_URL -f true

# infra
./build.sh -t $FLEET_URL -c $COURSE -1 true -7 $HTTP_AUTH -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL 

# services
if [[ -n "$K3S" ]]; then
    ./build.sh -9 $K3S -o serverless -t $FLEET_URL -c $COURSE -d true -n false -b false -s all -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL
else
    ./build.sh -o serverless -t $FLEET_URL -c $COURSE -d true -n false -b false -s all -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL
fi

# synthetics, profiling
./build.sh -o false -t $FLEET_URL -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL -p true -m true

# assets
if [[ -n "$WINDOWS_HOST_IP" ]]; then
    ./build.sh -o false -c $COURSE -d false -b false -s none -4 $WINDOWS_HOST_IP -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL -w true -e $REMOTE_ENDPOINT
else
    ./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL -w true -e $REMOTE_ENDPOINT
fi

# ramen
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL -2 true

# grafana
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL -g true

# windows
if [[ -n "$WINDOWS_HOST_IP" ]]; then
    ./build.sh -c $COURSE -3 true -4 $WINDOWS_HOST_IP -5 $WINDOWS_HOST_USERNAME -6 $WINDOWS_HOST_PASSWORD
fi