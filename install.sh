COURSE=o11y--course--field--100-e2e--serverless

OPTIND=1
while getopts "c:" opt
do
   case "$opt" in
      c ) COURSE="$OPTARG" ;;
   esac
done

retry_command_lin() {
    local max_attempts=256
    local timeout=2
    local attempt=1
    local exit_code=0

    while [ $attempt -le $max_attempts ]
    do
        "$@"
        exit_code=$?

        if [ $exit_code -eq 0 ]; then
            break
        fi

        printf "Attempt $attempt failed! Retrying in $timeout seconds...\n"
        sleep $timeout
        attempt=$(( attempt + 1 ))
    done

    if [ $exit_code -ne 0 ]; then
        printf "Command $@ failed after $attempt attempts!\n"
    fi

    return $exit_code
}

if [ -f ".env" ]; then
    set -o allexport # Automatically export all variables defined after this point
    source .env
    set +o allexport # Stop automatic exporting
fi

export I=99

HTTP_AUTH=true
envsubst '$COURSE,$ELASTICSEARCH_URL,$KIBANA_URL,$ELASTICSEARCH_APIKEY,$ACCESS_PASSWORD,$INGEST_URL,$FLEET_URL,$I,$HTTP_AUTH' < install/install.yaml | kubectl apply -f -
retry_command_lin kubectl logs -f job/superdemo-install-$I
