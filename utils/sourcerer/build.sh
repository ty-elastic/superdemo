arch=linux/amd64
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
course=latest
current_service=sourcerer

OPTIND=1
while getopts "c:" opt
do
   case "$opt" in
      c ) course="$OPTARG" ;;
   esac
done

docker buildx build --platform $arch \
    --progress plain -t $repo/$current_service:$course --output "type=registry,name=$repo/$current_service:$course" .
