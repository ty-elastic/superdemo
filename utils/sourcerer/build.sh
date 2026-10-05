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

if [[ "$course" == "o11y--course--field--100-e2e--serverless" ]]; then
   branch=main
elif [[ "$course" == "latest" ]]; then
   branch=main
elif [[ "$course" == "o11y--course--field--100-e2e--test" ]]; then
   branch=test
else
   branch=$course
fi

echo $branch
docker buildx build --platform $arch --build-arg BRANCH=$branch \
    --progress plain -t $repo/$current_service:$course --output "type=registry,name=$repo/$current_service:$course" .
