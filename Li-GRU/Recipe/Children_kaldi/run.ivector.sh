#!/bin/bash

set -euo pipefail

# This script contains the common feature preparation and
# iVector-related parts.

stage=0
train_set=train
test_sets=test

nnet3_affix=

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh

if [ $stage -le 3 ]; then
  # Create high-resolution MFCC features (with 40 cepstra instead of 13).
  # this shows how you can split across multiple file-systems.
  echo "$0: creating high-resolution MFCC features"
  for datadir in ${train_set} ${test_sets}; do
    utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
  done

  # do volume-perturbation on the training data prior to extracting hires
  # features; this helps make trained nnets more invariant to test data volume.
  utils/data/perturb_data_dir_volume.sh data/${train_set}_hires || exit 1;

  for datadir in ${train_set} ${test_sets}; do
    steps/make_mfcc.sh --nj $(nproc) --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd" data/${datadir}_hires || exit 1;
    steps/compute_cmvn_stats.sh data/${datadir}_hires || exit 1;
    utils/fix_data_dir.sh data/${datadir}_hires || exit 1;
  done
fi

if [ $stage -le 4 ]; then
  echo "$0: computing a subset of data to train the diagonal UBM."
  # We'll use about a quarter of the data.
  mkdir -p exp/nnet3${nnet3_affix}/diag_ubm
  temp_data_root=exp/nnet3${nnet3_affix}/diag_ubm

  num_utts_total=$(wc -l <data/${train_set}_hires/utt2spk)
  num_utts=$[$num_utts_total/4]
  utils/data/subset_data_dir.sh data/${train_set}_hires \
     $num_utts ${temp_data_root}/${train_set}_hires_subset

  echo "$0: computing a PCA transform from the hires data."
  steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
      --splice-opts "--left-context=3 --right-context=3" \
      --max-utts 10000 --subsample 2 \
       ${temp_data_root}/${train_set}_hires_subset \
       exp/nnet3${nnet3_affix}/pca_transform

  echo "$0: training the diagonal UBM."
  # Use 512 Gaussians in the UBM.
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj $(nproc) \
    --num-frames 700000 \
    --num-threads 1 \
    ${temp_data_root}/${train_set}_hires_subset 512 \
    exp/nnet3${nnet3_affix}/pca_transform exp/nnet3${nnet3_affix}/diag_ubm
fi

if [ $stage -le 5 ]; then
  # Train the iVector extractor.  Use all of the data since iVector extractors
  # can be sensitive to the amount of data.  The script defaults to an iVector dimension of
  # 100.
  echo "$0: training the iVector extractor"
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj $(nproc) --num-processes 1 --num-threads 1 \
     data/${train_set}_hires exp/nnet3${nnet3_affix}/diag_ubm \
     exp/nnet3${nnet3_affix}/extractor || exit 1;
fi

if [ $stage -le 6 ]; then
  # We extract iVectors on the training data after combining
  # short segments, which will be what we train the system on.  With
  # --utts-per-spk-max 2, the script pairs the utterances into twos, and treats
  # each of these pairs as one speaker; this gives more diversity in iVectors..
  # Note that these are extracted 'online'.

  # note, we don't encode the 'max2' in the name of the ivectordir even though
  # that's the data we extract the ivectors from, as it's still going to be
  # valid for the non-'max2' data, the utterance list is the same.

  ivectordir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_hires

  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  temp_data_root=${ivectordir}
  utils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
    data/${train_set}_hires ${temp_data_root}/${train_set}_hires_max2

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $(nproc) \
    ${temp_data_root}/${train_set}_hires_max2 \
    exp/nnet3${nnet3_affix}/extractor $ivectordir

  # Also extract iVectors for the test data.
  for data in $test_sets; do
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $(nproc) \
      data/${data}_hires exp/nnet3${nnet3_affix}/extractor \
      exp/nnet3${nnet3_affix}/ivectors_${data}_hires
  done
fi

exit 0
