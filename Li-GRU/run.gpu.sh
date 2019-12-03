docker build -t asr:initial .

sudo nvidia-smi -c 3
stamp=`date "+%Y%m%d-%H%M%S"`
mkdir /storage/Work_${stamp}
docker run -itd --name=asr --runtime=nvidia \
  -v /storage/audio:/storage/audio \
  -v /storage/Work_${stamp}:/storage/Work \
  asr:initial bash 
docker exec -itd asr ./run.recipe.sh
