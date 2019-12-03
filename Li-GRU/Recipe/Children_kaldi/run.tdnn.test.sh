#!/bin/bash

set -euo pipefail

# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).
stage=0
decode_nj=$(nproc)
train_set=train
test_sets=test
gmm=tri3b
nnet3_affix=

# The rest are configs specific to this script.  Most of the parameters
# are just hardcoded at this level, in the commands below.
affix=1h   # affix for the TDNN directory name
tree_affix=
train_stage=-10
get_egs_stage=-10
decode_iter=

# training options
# training chunk-options
chunk_width=140,100,160
dropout_schedule='0,0@0.20,0.3@0.50,0'
common_egs_dir=
xent_regularize=0.1

# training options
srand=0
remove_egs=true
reporting_email=

# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

# The iVector-extraction and feature-dumping parts are the same as the standard
# nnet3 setup, and you can skip them by setting "--stage 11" if you have already
# run those things.
run.ivector.tst1.sh --stage $stage \
                                  --train-set $train_set --test-sets $test_sets \
                                  --nnet3-affix "$nnet3_affix" || exit 1;

gmm_dir=exp/$gmm
ali_dir=exp/${gmm}_ali_${train_set}
tree_dir=exp/chain${nnet3_affix}/tree${tree_affix:+_$tree_affix}
lang=data/lang_chain
lat_dir=exp/chain${nnet3_affix}/${gmm}_${train_set}_lats
dir=exp/chain${nnet3_affix}/tdnn${affix}
train_data_dir=data/${train_set}_hires
lores_train_data_dir=data/${train_set}
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_hires

if [ $stage -le 15 ]; then
  # Note: it's not important to give mkgraph.sh the lang directory with the
  # matched topology (since it gets the topology file from the model).
  utils/mkgraph.sh \
    --self-loop-scale 1.0 data/lang_${test_sets} \
    $tree_dir $tree_dir/graph || exit 1;
fi

if [ $stage -le 16 ]; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  for part in $test_sets; do
    local/gen_fstscp.sh $tree_dir/graph data/${part}_hires
    steps/nnet3/decode.sh \
        --acwt 1.0 --post-decode-acwt 10.0 \
        --frames-per-chunk $frames_per_chunk \
        --nj $decode_nj --cmd "$decode_cmd"  --num-threads 1 \
        --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_${part}_hires \
        --scoring-opts "--min_lmwt 10 --max_lmwt 20" \
        $tree_dir/graph data/${part}_hires ${dir}/decode_${part} || exit 1
  done
fi

for x in exp/*/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
