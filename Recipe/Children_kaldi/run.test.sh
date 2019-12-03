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
  for part in test; do
    # use underscore-separated names in data directories.
    local/data_prep.sh $data/wav_$part data/$part $part
  done
fi

if [ $stage -le 1 ]; then
  local/format_lms.sh --src-dir data/lang_nosp data/local/lm test
fi

if [ $stage -le 2 ]; then
  for part in test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $(nproc) data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done
fi

if [ $stage -le 6 ]; then
  # Now we compute the pronunciation and silence probabilities from training data,
  # and re-create the lang directory.
  steps/get_prons.sh --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri3b
  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    exp/tri3b/pron_counts_nowb.txt exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt data/local/dict

  utils/prepare_lang.sh data/local/dict \
    "<UNK>" data/local/lang_tmp data/lang
  local/format_lms.sh --src-dir data/lang data/local/lm test

  # decode using the tri3b model with pronunciation and silence probabilities
  utils/mkgraph.sh data/lang_test \
    exp/tri3b exp/tri3b/graph
  local/gen_fstscp.sh exp/tri3b/graph data/test
  steps/decode_fmllr.sh --nj $(nproc) --cmd "$decode_cmd" \
    exp/tri3b/graph data/test \
    exp/tri3b/decode_test

  # Align utts using the tri2b model
  steps/align_fmllr.sh --nj $(nproc) --cmd "$train_cmd" \
    data/test data/lang exp/tri3b exp/tri3b_ali_test
fi

if [ $stage -le 7 ]; then
  for part in test; do
    steps/nnet/make_fmllr_feats.sh --nj $(nproc) --cmd "$train_cmd" \
      --transform-dir exp/tri3b_ali_$part \
      data-fmllr-tri3b/$part data/$part exp/tri3b \
      exp/make_fmllr/$part fmllr
    compute-cmvn-stats --spk2utt=ark:data-fmllr-tri3b/$part/spk2utt \
      scp:data-fmllr-tri3b/$part/feats.scp ark:fmllr/cmvn_$part.ark
    local/gen_fstscp.sh exp/tri3b/graph data-fmllr-tri3b/$part
  done

  local/gen_fstscp.sh exp/tri3b/graph data-fmllr-tri3b/test
  split_data.sh data-fmllr-tri3b/test $(nproc)
fi

for x in exp/*/decode*test*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
