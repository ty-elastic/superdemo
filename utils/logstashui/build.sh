export repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
export course=latest

OPTIND=1
while getopts "c:" opt
do
   case "$opt" in
      c ) course="$OPTARG" ;;
   esac
done

cd setup
./build.sh -c $course
cd ..

cd snmpsim
./build.sh -c $course
cd ..

