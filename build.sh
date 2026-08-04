#!/bin/bash

check_assets() {
    kubectl wait --for=condition=complete job/assets-$1 --timeout=5m
}

check_services() {
    kubectl -n $1 rollout status deployment --timeout=5m
}

get_lb_address() {
   printf "$FUNCNAME...\n"
    export SERVICE_IP=$(kubectl -n $1 get service $2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export SERVICE_PORT=$(kubectl -n $1 get service $2 -o jsonpath='{.spec.ports[0].port}')
    if [ -z "$SERVICE_IP" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   printf "$FUNCNAME...SUCCESS\n"
   return 0
}

join_by() {
  local IFS="$1"
  shift
  echo "$*"
}

arch=linux/amd64
course=latest
service=all
local=false
namespace_base=trading
region=na,emea
service_version="1.0"
assets=false
profiling=false
grafana=false
features=false
deploy_ebpf_services=false

build_infra=false
build_service=false
build_lib=false
deploy_otel=false
deploy_service=false
annotations=false
synthetics=false
prereq=false
remote=false
ramen=false
windows=false
http_auth=true
k3s=false

elasticsearch_es_endpoint="na"
elasticsearch_kibana_endpoint="na"
elasticsearch_api_key="na"
elasticsearch_otlp_endpoint="na"
elasticsearch_fleet_endpoint="na"
working_dir="$PWD"

proxy_port=8081

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    *)          machine="UNKNOWN:${unameOut}"
esac

OPTIND=1
while getopts "a:c:s:l:b:x:o:d:r:v:g:h:i:j:k:w:y:p:e:m:f:n:z:u:t:1:q:2:3:4:5:6:7:9:" opt
do
   case "$opt" in 
      1 ) prereq="$OPTARG" ;;
      2 ) ramen="$OPTARG" ;;
      3 ) windows="$OPTARG" ;;  

      4 ) windows_host_ip="$OPTARG" ;;
      5 ) windows_username="$OPTARG" ;;
      6 ) windows_password="$OPTARG" ;;  
      7 ) http_auth="$OPTARG" ;;  

      9 ) k3s="$OPTARG" ;;

      a ) arch="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      s ) service="$OPTARG" ;;
      l ) local="$OPTARG" ;;

      f ) features="$OPTARG" ;;
      g ) grafana="$OPTARG" ;;

      q ) build_infra="$OPTARG" ;;
      b ) build_service="$OPTARG" ;;
      x ) build_lib="$OPTARG" ;;

      o ) deploy_otel="$OPTARG" ;;
      d ) deploy_service="$OPTARG" ;;
      n ) deploy_ebpf_services="$OPTARG" ;;

      r ) region="$OPTARG" ;;
      v ) service_version="$OPTARG" ;;

      p ) profiling="$OPTARG" ;;
      e ) remote="$OPTARG" ;;

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;
      t ) elasticsearch_fleet_endpoint="$OPTARG" ;;

      m ) synthetics="$OPTARG" ;;

      w ) assets="$OPTARG" ;;
      y ) annotations="$OPTARG" ;;
      z ) working_dir="$OPTARG" ;;
      u ) logen="$OPTARG" ;;
   esac
done

echo "**COURSE=$course**"

echo working_dir=$working_dir
cd $working_dir

source $PWD/assets/scripts/retry.sh

export MYSQL_HOST=mysql
export MYSQL_USER=root
export MYSQL_PASSWORD=password
export MYSQL_DBNAME=main
export MYSQL_PORT=3306

export POSTGRESQL_HOST=postgresql
export POSTGRESQL_PORT=5432
export POSTGRESQL_USER=postgres
export POSTGRESQL_PASSWORD=postgres
export POSTGRESQL_DBNAME=postgres

# Save the original IFS to restore it later
OIFS="$IFS"
# Set IFS to the comma delimiter
IFS=","
# Create the array from the string
regions=($region)
# Restore the original IFS
IFS="$OIFS"

namespaces_array=()
for current_region in "${regions[@]}"; do
    namespace=$namespace_base-$current_region
    echo $namespace
    namespaces_array+=($namespace)
done
namespaces=$(join_by ", " "${namespaces_array[@]}")
echo $namespaces

repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
if [ "$local" = "true" ]; then
    docker run -d -p 5093:5000 --restart=always --name registry registry:2
    repo=localhost:5093
else
    if [[ "$build_service" == "true" || "$build_lib" == "true" ]]; then
        gcloud auth configure-docker us-central1-docker.pkg.dev
    fi
fi

if [ "$build_infra" = "true" ]; then
  cd ./assets
  ./build.sh -c $course
  cd ..

  cd ./utils/remote
  ./build.sh -c $course
  cd ../..

  cd ./utils/logen
  ./build.sh -c $course
  cd ../..

  cd ./utils/ramen
  ./build.sh -c $course
  cd ../..

  cd ./utils/wiki.js/postgresql
  ./build.sh -c $course
  cd ../../..

  cd ./utils/wiki.js/install
  ./build.sh -c $course
  cd ../../..

  cd ./utils/prometheus-grafana
  ./build.sh -c $course
  cd ../..

  cd ./utils/prometheus-grafana/mig-to-kbn
  ./build.sh -c $course
  cd ../../..

#   cd ./utils/semantic-code-search
#   ./build.sh -c $course
#   cd ../..

  cd ./utils/sourcerer
  ./build.sh -c $course
  cd ../..

  cd ./utils/dockerhost
  ./build.sh -c $course
  cd ../..
fi

if [ "$build_service" = "true" ]; then
    cd ./src
    $PWD/build.sh -k $service_version -r $repo -s $service -c $course -a $arch
    cd ..
fi

if [ "$build_lib" = "true" ]; then
    cd ./lib
    $PWD/build.sh -r $repo -c $course -a $arch
    cd ..
fi


if [ "$prereq" == "true" ]; then
    source $PWD/utils/ksm/ksm.sh

    source $PWD/utils/traefik/install.sh -s $PWD -7 $http_auth
fi

if [ "$deploy_otel" != "false" ]; then
    # ---------- COLLECTOR
    if [ "$deploy_otel" = "true" ]; then
        deploy_otel="stack"
    fi

    source $PWD/assets/scripts/otel.sh -9 $k3s -t $elasticsearch_fleet_endpoint -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint -o $deploy_otel
fi

if [ "$features" = "true" ]; then

    retry_command_lin check_http $elasticsearch_kibana_endpoint
    retry_command_lin check_http $elasticsearch_es_endpoint
    retry_command_lin check_http $elasticsearch_otlp_endpoint
    retry_command_lin check_http $elasticsearch_fleet_endpoint

    source $PWD/assets/scripts/features_es.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
    source $PWD/assets/scripts/snowem.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -e https://snowem-v2-voldmqr2bq-uc.a.run.app
fi

if [ "$prereq" == "true" ]; then

    source $PWD/utils/kafka/install.sh -v $PWD/utils/kafka/values.yaml

    source $PWD/assets/scripts/integration_packages.sh
    install_integration_package "kafka_otel" $elasticsearch_kibana_endpoint $elasticsearch_api_key

    kubectl apply -f utils/redis/redis.yml

    kubectl --namespace infra delete secret generic elastic-secret-otel
    kubectl create secret generic elastic-secret-otel \
        --namespace infra \
        --from-literal=elastic_otlp_endpoint="$elasticsearch_otlp_endpoint" \
        --from-literal=elastic_endpoint="$elasticsearch_es_endpoint" \
        --from-literal=elastic_fleet_endpoint="$elasticsearch_fleet_endpoint" \
        --from-literal=elastic_kibana_endpoint="$elasticsearch_kibana_endpoint" \
        --from-literal=elastic_fleet_opamp_api_key="$OPAMP_API_KEY" \
        --from-literal=elastic_api_key="$elasticsearch_api_key"

    kubectl apply -f utils/sourcerer/setup.yaml
    kubectl -n infra wait --for=condition=complete job/src-code-setup --timeout=5m
    kubectl apply -f utils/sourcerer/indexer.yaml
fi

printf "deploying services...\n"
for current_region in "${regions[@]}"; do
    namespace=$namespace_base-$current_region
    printf "setup for namespace=$namespace\n"

    export COURSE=$course
    export REPO=$repo
    export NAMESPACE=$namespace
    export REGION=$current_region

    ((proxy_port++))
    export PROXY_PORT=$proxy_port

    if [[ "$deploy_service" == "true" || "$deploy_service" == "delete" || "$deploy_service" == "force" ]]; then
        export SERVICE_VERSION=$service_version

        export JOB_ID=$(( $RANDOM ))
        #echo $JOB_ID

        envsubst '$NAMESPACE' < k8s/_namespace.yaml | kubectl apply -f -

        kubectl --namespace $NAMESPACE delete secret generic elastic-secret-otel
        kubectl create secret generic elastic-secret-otel \
            --namespace $NAMESPACE \
            --from-literal=elastic_otlp_endpoint="$elasticsearch_otlp_endpoint" \
            --from-literal=elastic_endpoint="$elasticsearch_es_endpoint" \
            --from-literal=elastic_fleet_endpoint="$elasticsearch_fleet_endpoint" \
            --from-literal=elastic_fleet_opamp_api_key="$OPAMP_API_KEY" \
            --from-literal=elastic_api_key="$elasticsearch_api_key"

        if [ "$service" != "none" ]; then
            for file in k8s/*.yaml; do
                current_service=$(basename "$file")
                current_service="${current_service%.*}"

                if [[ "$service" == "all" || "$service" == "$current_service" ]]; then

                    if [[ "$current_service" == "recorder-go-zero" && $deploy_ebpf_services == "false" ]]; then
                        printf "deleting $current_service from region $REGION\n"
                        envsubst '$MYSQL_HOST,$MYSQL_USER,$MYSQL_PASSWORD,$MYSQL_DBNAME,$MYSQL_PORT,$POSTGRESQL_HOST,$POSTGRESQL_PORT,$POSTGRESQL_DBNAME,$POSTGRESQL_USER,$POSTGRESQL_PASSWORD,$JOB_ID,$SERVICE_VERSION,$COURSE,$REPO,$NAMESPACE,$REGION' < k8s/$current_service.yaml | kubectl delete -f -
                        printf "skipping recorder-go-zero deployment...\n"
                        continue
                    fi

                    if [ "$deploy_service" = "delete" ]; then
                        printf "deleting $current_service from region $REGION\n"
                        envsubst '$MYSQL_HOST,$MYSQL_USER,$MYSQL_PASSWORD,$MYSQL_DBNAME,$MYSQL_PORT,$POSTGRESQL_HOST,$POSTGRESQL_PORT,$POSTGRESQL_DBNAME,$POSTGRESQL_USER,$POSTGRESQL_PASSWORD,$JOB_ID,$SERVICE_VERSION,$COURSE,$REPO,$NAMESPACE,$REGION' < k8s/$current_service.yaml | kubectl delete -f -
                    else

                        printf "deploying $current_service to region $REGION\n"
                        #echo $PROXY_PORT
                        #envsubst '$MYSQL_HOST,$MYSQL_USER,$MYSQL_PASSWORD,$MYSQL_DBNAME,$MYSQL_PORT,$POSTGRESQL_HOST,$POSTGRESQL_PORT,$POSTGRESQL_DBNAME,$POSTGRESQL_USER,$POSTGRESQL_PASSWORD,$JOB_ID,$SERVICE_VERSION,$COURSE,$REPO,$NAMESPACE,$REGION' < k8s/$current_service.yaml | yq '.spec.ports[].port |= to_number'

                        cat k8s/$current_service.yaml > tmp.yaml
                        sed "s/{PROXY_PORT}/$PROXY_PORT/g" tmp.yaml > tmp2.yaml
                        envsubst '$MYSQL_HOST,$MYSQL_USER,$MYSQL_PASSWORD,$MYSQL_DBNAME,$MYSQL_PORT,$POSTGRESQL_HOST,$POSTGRESQL_PORT,$POSTGRESQL_DBNAME,$POSTGRESQL_USER,$POSTGRESQL_PASSWORD,$JOB_ID,$SERVICE_VERSION,$COURSE,$REPO,$NAMESPACE,$REGION' < tmp2.yaml | kubectl apply -f -
                        rm tmp.yaml
                        rm tmp2.yaml

                        if [ "$deploy_service" = "force" ]; then
                            kubectl -n $namespace rollout restart deployment/$current_service
                        fi

                        if [ "$annotations" = "true" ]; then
                            printf "adding deployment annotation for $current_service\n"
                            if [ "$machine" == "Mac" ]; then
                                ts=$(date -z utc +%FT%TZ)
                            elif [ "$machine" == "Linux" ]; then
                                ts=$(date --utc +%FT%TZ)
                            fi
                            curl -X POST "$elasticsearch_kibana_endpoint/api/apm/services/$current_service/annotation" \
                                -H 'Content-Type: application/json' \
                                -H 'kbn-xsrf: true' \
                                -H "Authorization: ApiKey ${elasticsearch_api_key}" \
                                -d '{
                                    "@timestamp": "'$ts'",
                                    "service": {
                                        "environment": "'$namespace'",
                                        "version": "'$SERVICE_VERSION'"
                                    },
                                    "message": "service_deployment='$SERVICE_VERSION'"
                                }'
                        fi
                    fi
                fi
            done
        fi
    fi
done
printf "deploying services...SUCCESS\n"

if [ "$profiling" = "true" ]; then
    source $PWD/assets/scripts/profiling.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
fi

if [ "$synthetics" = "true" ]; then
    source $PWD/assets/scripts/synthetics.sh -t $elasticsearch_fleet_endpoint -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
fi

if [[ "$remote" != "false" ]]; then
    printf "deploying remote_endpoint...\n"

    cd utils/remote

    envsubst '$COURSE,$REPO' < remote.yaml | kubectl apply -f -
    cd ../..

    if [ "$remote" = "true"  ]; then
        retry_command_lin get_lb_address traefik traefik
        export remote_endpoint=http://$SERVICE_IP:9014
    else
        export remote_endpoint=$remote
    fi

    printf "deploying remote_endpoint $remote_endpoint...SUCCESS\n"
fi

if [ "$ramen" = "true"  ]; then
    printf "deploying ramen...\n"

    cd utils/ramen

    export elasticsearch_kibana_endpoint=$elasticsearch_kibana_endpoint
    export elasticsearch_es_endpoint=$elasticsearch_es_endpoint
    export elasticsearch_api_key=$elasticsearch_api_key 
    export COURSE=$COURSE
    export REPO=$REPO

    envsubst '$COURSE,$REPO,$elasticsearch_kibana_endpoint,$elasticsearch_api_key,$elasticsearch_es_endpoint' < ramen.yaml  | kubectl apply -f -
    
    cd ../..

    source $PWD/assets/scripts/ramen.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint 

    printf "deploying ramen...SUCCESS\n"
fi

if [ "$ramen" = "true"  ]; then
    printf "deploying dockerhost...\n"

    cd utils/dockerhost

    export COURSE=$COURSE
    export REPO=$REPO

    envsubst '$COURSE,$REPO' < dockerhost.yaml  | kubectl apply -f -
    
    cd ../..

    printf "deploying dockerhost...SUCCESS\n"
fi

if [ "$assets" = "true" ]; then
    printf "deploying assets...\n"

    cd assets

    export JOB_ID=$(( $RANDOM ))
    #echo $JOB_ID
    export elasticsearch_kibana_endpoint=$elasticsearch_kibana_endpoint
    export elasticsearch_es_endpoint=$elasticsearch_es_endpoint
    export elasticsearch_api_key=$elasticsearch_api_key  
    export remote_endpoint=$remote_endpoint
    export namespaces=$namespaces
    export iis_endpoint="http://$windows_host_ip"
    echo $windows_host_ip
    echo $iis_endpoint

    envsubst '$JOB_ID,$COURSE,$REPO,$iis_endpoint,$elasticsearch_kibana_endpoint,$elasticsearch_es_endpoint,$elasticsearch_api_key,$remote_endpoint,$namespaces' < assets.yaml | kubectl apply -f -
    cd ..

    retry_command_lin check_assets $JOB_ID
    #retry_command_lin kubectl logs -f job/assets-$JOB_ID

    for current_region in "${regions[@]}"; do
        namespace=$namespace_base-$current_region

        if [[ "$service" == "all" || "$service" == "monkey" ]]; then
            check_services $namespace
            printf "check services for $namespace\n"
        fi
    done
    source $PWD/assets/scripts/features_dep.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint

    source $PWD/utils/wiki.js/install.sh -c $course -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -s $PWD

    printf "deploying assets...SUCCESS\n"
fi

if [ "$grafana" = "true" ]; then
    printf "deploying grafana...\n"

    cd utils/prometheus-grafana

    export elasticsearch_es_endpoint=$elasticsearch_es_endpoint
    export elasticsearch_kibana_endpoint=$elasticsearch_kibana_endpoint
    export elasticsearch_api_key=$elasticsearch_api_key  
    export COURSE=$course
    export REPO=$repo

    envsubst '$COURSE,$REPO,$elasticsearch_es_endpoint,$elasticsearch_api_key' < grafana.yaml | kubectl apply -f -
    check_services infra
    retry_command_lin check_http "http://grafana.infra.svc.cluster.local:3000/"
    envsubst '$elasticsearch_kibana_endpoint,$elasticsearch_es_endpoint,$elasticsearch_api_key,$COURSE,$REPO' < migrate.yaml | kubectl apply -f -

    cd ../..
    printf "deploying grafana...SUCCESS\n"
fi

if [ "$logen" = "true" ]; then
    printf "deploying logen...\n"
    cd utils/logen

    export COURSE=$course
    export REPO=$repo

    envsubst '$COURSE,$REPO' < logen.yaml | kubectl apply -f -
    cd ../..
    printf "deploying logen...SUCCESS\n"
fi

if [ "$windows" = "true" ]; then
    printf "deploying windows...\n"
    cd utils/windows

    export WINDOWS_HOST=$windows_host_ip
    export WINDOWS_HOST_USERNAME=$windows_username
    export WINDOWS_HOST_PASSWORD=$windows_password

    envsubst '$WINDOWS_HOST,$WINDOWS_HOST_USERNAME,$WINDOWS_HOST_PASSWORD' < windows.yaml | kubectl apply -f -
    cd ../..

    source $PWD/utils/windows/install.sh -c $COURSE -4 $windows_host_ip -5 $windows_username -6 $windows_password -7 $PWD/utils/windows/setup.ps1

    printf "deploying windows...SUCCESS\n"
fi
