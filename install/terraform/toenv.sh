


#terraform output -raw course

export COURSE=$(terraform output -raw course)
echo $COURSE

export ELASTICSEARCH_URL=$(terraform output -raw elasticsearch_url)
export elasticsearch_es_endpoint=$(terraform output -raw elasticsearch_url)
echo $ELASTICSEARCH_URL

export elasticsearch_apikey=$(terraform output -raw elasticsearch_apikey)

export KIBANA_URL=$(terraform output -raw kibana_url)
echo $KIBANA_URL

export ACCESS_PASSWORD=$(terraform output -raw access_password)
echo $ACCESS_PASSWORD

export INGEST_URL=$(terraform output -raw ingest_url)
echo $INGEST_URL

export FLEET_URL=$(terraform output -raw fleet_url)
echo $FLEET_URL

export HTTP_AUTH=true
export REMOTE_ENDPOINT=true
export K3S=false
