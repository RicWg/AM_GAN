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
  for part in test train; do
    # use underscore-separated names in data directories.
    local/data_prep.sh $data/wav_$part data/$part $part
  done
fi

if [ $stage -le 1 ]; then
  mkdir -p data/local/lm
  ln -s $data/{lm_*,items.*,lexicon,vocab} data/local/lm

  # when the "--stage 3" option is used below we skip the G2P steps, and use the
  # lexicon we have already downloaded from openslr.org/11/
  local/prepare_dict.sh --stage 3 --nj $(nproc) --cmd "$train_cmd" \
    data/local/lm data/local/lm data/local/dict_nosp

  utils/prepare_lang.sh data/local/dict_nosp \
    "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  local/format_lms.sh --src-dir data/lang_nosp data/local/lm test
fi

if [ $stage -le 2 ]; then
  for part in test train; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $(nproc) data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done
fi

if [ $stage -le 3 ]; then
  utils/subset_data_dir.sh data/train 12000 data/train_mono

  # train a monophone system
  steps/train_mono.sh --boost-silence 1.25 --nj $(nproc) --cmd "$train_cmd" \
    data/train_mono data/lang_nosp exp/mono

  steps/align_si.sh --boost-silence 1.25 --nj $(nproc) --cmd "$train_cmd" \
    data/train data/lang_nosp exp/mono exp/mono_ali_train
fi

if [ $stage -le 4 ]; then
  # train a first delta + delta-delta triphone system on all utterances
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    3500 40000 data/train data/lang_nosp exp/mono_ali_train exp/tri1

  steps/align_si.sh --nj $(nproc) --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri1 exp/tri1_ali_train
fi

if [ $stage -le 5 ]; then
  # train an LDA+MLLT system.
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 4000 50000 \
    data/train data/lang_nosp exp/tri1_ali_train exp/tri2b

  # Align utts using the tri2b model
  steps/align_si.sh  --nj $(nproc) --cmd "$train_cmd" --use-graphs true \
    data/train data/lang_nosp exp/tri2b exp/tri2b_ali_train
fi

if [ $stage -le 6 ]; then
  # Train tri3b, which is LDA+MLLT+SAT
  steps/train_sat.sh --cmd "$train_cmd" 4000 50000 \
    data/train data/lang_nosp exp/tri2b_ali_train exp/tri3b

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
    data/train data/lang exp/tri3b exp/tri3b_ali_train
 
  steps/align_fmllr.sh --nj $(nproc) --cmd "$train_cmd" \
    data/test data/lang exp/tri3b exp/tri3b_ali_test
fi

if [ $stage -le 7 ]; then
  for part in test train; do
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
