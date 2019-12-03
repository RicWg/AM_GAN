#!/bin/bash

# Copyright 2014  Vassil Panayotov
#           2014  Johns Hopkins University (author: Daniel Povey)
# Apache 2.0

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <src-dir> <dst-dir> <sec>"
  echo "e.g.: $0 /export/a15/vpanayotov/data/LibriSpeech/dev-clean data/dev-clean dev"
  exit 1
fi

src=$1
dst=$2
sec=$3

mkdir -p $dst || exit 1;

[ ! -d $src ] && echo "$0: no such directory $src" && exit 1;


wav_scp=$dst/wav.scp; [[ -f "$wav_scp" ]] && rm $wav_scp
trans=$dst/text; [[ -f "$trans" ]] && rm $trans
utt2spk=$dst/utt2spk; [[ -f "$utt2spk" ]] && rm $utt2spk
utt2dur=$dst/utt2dur; [[ -f "$utt2dur" ]] && rm $utt2dur

for chapter_dir in $(find -L $src/ -mindepth 1 -maxdepth 1 -type d | sort); do
  chapter=$(basename $chapter_dir)
  if ! [ "$chapter" -eq "$chapter" ]; then  # not integer.
    echo "$0: unexpected chapter-subdirectory name $chapter"
    exit 1;
  fi

  find -L $chapter_dir/ -iname "*.au" | sort | xargs -I% basename % .au | \
    awk -v "dir=$chapter_dir" '{printf "%s sox -t au -e u-law -r 8k %s/%s.au -t wavpcm -e signed-integer -r 8k -b 16 -c 1 - |\n", $0, dir, $0}' >>$wav_scp|| exit 1

  # NOTE: For now we are using per-chapter utt2spk. That is each chapter is considered
  #       to be a different speaker. This is done for simplicity and because we want
  #       e.g. the CMVN to be calculated per-chapter
  ls $chapter_dir/*.au | grep -Po '(([0-9])|(\.))+\.au' | sed -r 's/\.au$//' | \
    awk -v "chapter=$chapter" '{printf "%s %s\n", $1, chapter}' >>$utt2spk || exit 1

done

cat $src/../trans.${sec}.inuse | sort -u > $trans

spk2utt=$dst/spk2utt
utils/utt2spk_to_spk2utt.pl <$utt2spk >$spk2utt || exit 1

ntrans=$(wc -l <$trans)
nutt2spk=$(wc -l <$utt2spk)
! [ "$ntrans" -eq "$nutt2spk" ] && \
  echo "Inconsistent #transcripts($ntrans) and #utt2spk($nutt2spk)" && exit 1;

utils/data/get_utt2dur.sh --nj $(nproc) $dst 1>&2 || exit 1

utils/validate_data_dir.sh --no-feats $dst || exit 1;

echo "$0: successfully prepared data in $dst"

exit 0
