
root="../../"
http_auth=true

OPTIND=1
while getopts "s:7:8:" opt
do
   case "$opt" in
      s ) root="$OPTARG" ;;
      7 ) http_auth="$OPTARG" ;; 
      8 ) access_password="$OPTARG" ;;
   esac
done

source $root/assets/scripts/retry.sh

if [ "$http_auth" = "true"  ]; then
  helm repo add traefik https://traefik.github.io/charts
  helm repo update
  helm install traefik traefik/traefik \
    --namespace traefik \
    --create-namespace \
    -f $root/utils/traefik/values.yaml

  kubectl create secret generic traefik-auth --namespace=traefik \
    --from-literal=username=admin \
    --from-literal=password=$access_password

  kubectl delete secret --namespace=traefik traefik-auth-encoded
  htpasswd -b -c .htpasswd admin $access_password
  kubectl create secret generic traefik-auth-encoded --from-file=.htpasswd --namespace=traefik
  rm -rf .htpasswd

  kubectl apply -f $root/utils/traefik/auth.yaml

  retry_command_lin get_lb_address traefik traefik
else
  echo "k3s traefik"
  #mkdir -p /var/lib/rancher/k3s/server/manifests
  #cp $root/utils/traefik/k3s.yaml /var/lib/rancher/k3s/server/manifests/traefik-config.yaml
  kubectl apply -f $root/utils/traefik/noauth.yaml

  #retry_command_lin get_lb_address kube-system traefik
fi
