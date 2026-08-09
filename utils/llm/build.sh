arch=linux/amd64
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
course=latest


OPTIND=1
while getopts "c:" opt
do
   case "$opt" in
      c ) course="$OPTARG" ;;
   esac
done

git clone -b ty-elastic/elasticsearch_llm --single-branch --depth 1 https://github.com/ty-elastic/litellm.git
cd litellm

current_service=litellm
docker buildx build --platform $arch \
    --progress plain -t $repo/$current_service:$course --output "type=registry,name=$repo/$current_service:$course" .

cd ..
rm -rf litellm


git clone -b main --single-branch --depth 1 https://github.com/BerriAI/example_openai_endpoint.git
cd example_openai_endpoint

current_service=mock-openai
docker buildx build --platform $arch \
    --progress plain -t $repo/$current_service:$course --output "type=registry,name=$repo/$current_service:$course" .

cd ..
rm -rf example_openai_endpoint
