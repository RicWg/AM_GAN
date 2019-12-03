#!/bin/bash

# Change this location to somewhere where you want to put the data.
data=/storage/Work/common
mfccdir=mfcc
stage=0

. ./cmd.sh
. ./path.sh
. parse_options.sh

set -euo pipefail

if [ $stage -le 0 ]; then
  # format the data as Kaldi data directories
  for part in dev; do
    # use underscore-separated names in data directories.
    local/data_prep.sh $data/wav_$part data/$part $part
  done
fi

if [ $stage -le 2 ]; then
  for part in dev; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $(nproc) data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done
fi

if [ $stage -le 6 ]; then
  # Align utts using the tri2b model
  steps/align_fmllr.sh --nj $(nproc) --cmd "$train_cmd" \
    data/dev data/lang exp/tri3b exp/tri3b_ali_dev
fi

if [ $stage -le 7 ]; then
  for part in dev; do
    steps/nnet/make_fmllr_feats.sh --nj $(nproc) --cmd "$train_cmd" \
      --transform-dir exp/tri3b_ali_$part \
      data-fmllr-tri3b/$part data/$part exp/tri3b \
      exp/make_fmllr/$part fmllr
    compute-cmvn-stats --spk2utt=ark:data-fmllr-tri3b/$part/spk2utt \
      scp:data-fmllr-tri3b/$part/feats.scp ark:fmllr/cmvn_$part.ark
    local/gen_fstscp.sh exp/tri3b/graph data-fmllr-tri3b/$part
  done

  local/gen_fstscp.sh exp/tri3b/graph data-fmllr-tri3b/dev
  split_data.sh data-fmllr-tri3b/dev $(nproc)
fi
