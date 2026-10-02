
#!/bin/bash
root="../../"

OPTIND=1
while getopts "s:" opt
do
   case "$opt" in
      s ) root="$OPTARG" ;;
   esac
done

source $root/assets/scripts/retry.sh

mattermost_url="http://mattermost.infra.svc.cluster.local:8065"

OPTIND=1
while getopts "m:" opt
do
   case "$opt" in
      m ) mattermost_url="$OPTARG" ;;
   esac
done

response=$(curl -i -v -H POST "$mattermost_url/api/v4/users/login" \
     -H 'Content-Type: application/json' \
     --header "X-Requested-With: XMLHttpRequest" \
     -d '{
       "login_id": "user",
       "password": "password"
     }')

echo $response
MMAUTHTOKEN=$(echo $response grep -Fi "Set-Cookie:" | sed -n -E 's/.*MMAUTHTOKEN=([^;]+).*/\1/p')
MMCSRF=$(echo $response grep -Fi "Set-Cookie:" | sed -n -E 's/.*MMCSRF=([^;]+).*/\1/p')
MMUSERID=$(echo $response grep -Fi "Set-Cookie:" | sed -n -E 's/.*MMUSERID=([^;]+).*/\1/p')


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
  replacePathRegex:
    regex: ^/hooks/(.*)
    replacement: /hooks/$webhook_id
EOF

kubectl apply -f $root/utils/mattermost/mattermost.yaml
kubectl apply -f $root/utils/mattermost/dynamic.yaml

rm -rf $root/utils/mattermost/dynamic.yaml

