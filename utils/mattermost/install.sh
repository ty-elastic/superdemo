
#!/bin/bash
root="../../"
mattermost_url="http://mattermost.infra.svc.cluster.local:8065"

OPTIND=1
while getopts "s:m:" opt
do
   case "$opt" in
      s ) root="$OPTARG" ;;
      m ) mattermost_url="$OPTARG" ;;
   esac
done

source $root/assets/scripts/retry.sh

kubectl apply -f $root/utils/mattermost/mattermost.yaml
kubectl wait -n infra --for=condition=Ready pod -l service=mattermost --timeout=5m

mm_login() {
    printf "$FUNCNAME...\n"

   response=$(curl -i -v -H POST "$mattermost_url/api/v4/users/login" \
     -H 'Content-Type: application/json' \
     --header "X-Requested-With: XMLHttpRequest" \
     -d '{
       "login_id": "user",
       "password": "password"
     }')

    export MMAUTHTOKEN=$(echo $response grep -Fi "Set-Cookie:" | sed -n -E 's/.*MMAUTHTOKEN=([^;]+).*/\1/p')
    export MMCSRF=$(echo $response grep -Fi "Set-Cookie:" | sed -n -E 's/.*MMCSRF=([^;]+).*/\1/p')
    export MMUSERID=$(echo $response grep -Fi "Set-Cookie:" | sed -n -E 's/.*MMUSERID=([^;]+).*/\1/p')


    if [[ -z "$MMAUTHTOKEN" ]]; then
        printf "$FUNCNAME...ERROR: MMAUTHTOKEN is unset\n"
        return 1
    fi
    printf "$FUNCNAME...MMAUTHTOKEN=$MMAUTHTOKEN\n"
    return 0
}
retry_command_lin mm_login

echo $MMAUTHTOKEN
echo $MMCSRF
echo $MMUSERID

response=$(curl --location --request POST "$mattermost_url/api/v4/teams" \
 -H "Cookie: MMAUTHTOKEN=$MMAUTHTOKEN" --header "X-Requested-With: XMLHttpRequest" \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "it",
    "display_name": "IT",
    "type": "O"
}')
echo $response




response=$(curl -v -X GET $mattermost_url/api/v4/users/me/teams \
  -H "Cookie: MMAUTHTOKEN=$MMAUTHTOKEN" --header "X-Requested-With: XMLHttpRequest")

team_id=$(echo $response | jq -r '.[0].id')
echo $team_id
echo $response

response=$(curl -X POST "$mattermost_url/api/v4/channels" \
    -H "Cookie: MMAUTHTOKEN=$MMAUTHTOKEN" \
    --header "X-Requested-With: XMLHttpRequest" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d '{
        "team_id": "'$team_id'",
        "name": "incidents",
        "display_name": "incidents",
        "type": "O"
    }')

echo $response
channel_id=$(echo $response | jq -r '.id')
echo $channel_id

response=$(curl -X POST $mattermost_url/api/v4/hooks/incoming \
  -H "Cookie: MMAUTHTOKEN=$MMAUTHTOKEN" \
  --header "X-Requested-With: XMLHttpRequest" \
  --header 'Content-Type: application/json' \
  --data '{
    "channel_id": "'$channel_id'",
    "display_name": "Elastic",
    "description": "incidents"
  }')

webhook_id=$(echo $response | jq -r '.id')
echo $webhook_id

export MM_WEBHOOK="/hooks/$webhook_id"

echo $MM_WEBHOOK

# apiVersion: traefik.io/v1alpha1
# kind: Middleware
# metadata:
#   name: mattermost-auth
#   namespace: traefik
# spec:
#   headers:
#     customRequestHeaders:
#       "Cookie": "MMAUTHTOKEN=$MMAUTHTOKEN; MMUSERID=$MMUSERID"
#       "Authorization": "Bearer $MMAUTHTOKEN"
#       "X-Requested-With": "XMLHttpRequest"

cat > "$root/utils/mattermost/dynamic.yaml" <<EOF
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: mattermost-hooks
  namespace: traefik
spec:
  replacePath:
    path: /hooks/$webhook_id
EOF


kubectl apply -f $root/utils/mattermost/dynamic.yaml

rm -rf $root/utils/mattermost/dynamic.yaml

