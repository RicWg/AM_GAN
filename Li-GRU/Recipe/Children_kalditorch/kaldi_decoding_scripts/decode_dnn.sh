#!/bin/bash


# Copyright 2013    Yajie Miao    Carnegie Mellon University
# Apache 2.0

# Decode the DNN model. The [srcdir] in this script should be the same as dir in
# build_nnet_pfile.sh. Also, the DNN model has been trained and put in srcdir.
# All these steps will be done automatically if you run the recipe file run-dnn.sh

# Modified 2018 Mirco Ravanelli Univeristé de Montréal - Mila


cfg_file=$1
out_folder=$2



# Reading the options in the cfg file
source <(grep = $cfg_file | sed 's/ *= */=/g')

cd $decoding_script_folder

. ./path.sh


## Begin configuration section
num_threads=1
stage=0


echo "$0 $@"  # Print the command line for logging

. ./parse_options.sh || exit 1;

if [ $# != 4 ]; then
   echo "Wrong #arguments ($#, expected 4)"
   echo "Usage: steps/decode_dnn.sh <cfg-file> <out-folder> <featstring> <fstlist>"
   exit 1;
fi



dir=`echo $out_folder | sed 's:/$::g'` # remove any trailing slash.
featstring=$3
fstlist=$4
srcdir=`dirname $dir`; # assume model directory one level up from decoding directory.

thread_string=
[ $num_threads -gt 1 ] && thread_string="-parallel --num-threads=$num_threads"


mkdir -p $dir/log

arr_ck=($(ls $featstring))
fst_ck=($(ls $fstlist))

nj=${#arr_ck[@]}

sdata=$data/split$nj;
echo $nj > $dir/num_jobs

# Some checks.  Note: we don't need $srcdir/tree but we expect
# it should exist, given the current structure of the scripts.
for f in $graphdir/HCLG.fst $data/feats.scp; do
  [ ! -e $f ] && echo "$0: no such file $f" && exit 1;
done

if [ $stage -le 1 ]; then
  JOB=1
  for ck_data in "${arr_ck[@]}"
  do
    CHK=$((JOB-1))
    finalfeats="ark,s,cs: cat $ck_data |"
    finalfsts="scp:${fst_ck[$CHK]}"
    latgen-faster-mapped$thread_string --min-active=$min_active --max-active=$max_active --max-mem=$max_mem --beam=$beam --lattice-beam=$latbeam --acoustic-scale=$acwt --allow-partial=true --word-symbol-table=$graphdir/words.txt $alidir/final.mdl "$finalfsts" "$finalfeats" "ark:|gzip -c > $dir/lat.$JOB.gz" &> $dir/log/decode.$JOB.log &
    JOB=$((JOB+1))
  done
  wait
fi


# Copy the source model in order for scoring
cp $alidir/final.mdl $srcdir
  

if ! $skip_scoring ; then
  [ ! -x $scoring_script ] && \
    echo "$0: not scoring because local/score.sh does not exist or not executable." && exit 1;
  $scoring_script $scoring_opts $data $graphdir $dir
fi

exit 0;
