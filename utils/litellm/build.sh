arch=linux/amd64
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
course=latest
current_service=litellm

OPTIND=1
while getopts "c:" opt
do
   case "$opt" in
      c ) course="$OPTARG" ;;
   esac
done

git clone -b ty-elastic/elasticsearch_llm --single-branch --depth 1 https://github.com/ty-elastic/litellm.git
cd litellm

docker buildx build --platform $arch \
    --progress plain -t $repo/$current_service:$course --output "type=registry,name=$repo/$current_service:$course" .

cd ..
rm -rf litellm