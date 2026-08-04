#!/bin/bash

source $PWD/assets/scripts/retry.sh
source $PWD/assets/scripts/integration_packages.sh

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

export AGENT_VERSION=9.5.0

config_profiling_agent() {
    printf "$FUNCNAME...\n"
    envsubst '$AGENT_VERSION' < agents/profiling/profiler.yaml | kubectl apply -f -
    printf "$FUNCNAME...SUCCESS\n"
}
config_profiling_agent

config_profiling() {
    printf "$FUNCNAME...\n"

    # fast path
    install_integration_package "profilingmetrics_otel" $elasticsearch_kibana_endpoint $elasticsearch_api_key
    if [ $? -ne 0 ]; then
        printf "$FUNCNAME...install_package failed\n"
        return 1
    fi

    printf "$FUNCNAME...SUCCESS\n"
    return 0
}
retry_command_lin config_profiling
