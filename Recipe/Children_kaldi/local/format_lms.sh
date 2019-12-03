#!/bin/bash

# Copyright 2014 Vassil Panayotov
# Apache 2.0

# Prepares the test time language model(G) transducers
# (adapted from wsj/s5/local/wsj_format_data.sh)

. ./path.sh || exit 1;

# begin configuration section
src_dir=data/lang
# end configuration section

. utils/parse_options.sh || exit 1;

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <lm-dir> <lm_suffix>"
  echo "e.g.: $0 /export/a15/vpanayotov/data/lm test"
  echo ", where:"
  echo "    <lm-dir> is the directory in which the language model is stored/downloaded"
  echo "Options:"
  echo "   --src-dir  <dir>           # source lang directory, default data/lang"
  exit 1
fi

lm_dir=$1
lm_suffix=$2

if [ ! -d $lm_dir ]; then
  echo "$0: expected source LM directory $lm_dir to exist"
  exit 1;
fi
if [ ! -f $src_dir/words.txt ]; then
  echo "$0: expected $src_dir/words.txt to exist."
  exit 1;
fi


tmpdir=data/local/lm_tmp.$$
trap "rm -r $tmpdir" EXIT

mkdir -p $tmpdir

for lm_suffix in `echo ${lm_suffix}`; do
  # tglarge is prepared by a separate command, called from run.sh; we don't
  # want to compile G.fst for tglarge, as it takes a while.
  test=${src_dir}_${lm_suffix}
  mkdir -p $test/G.fst
  cp -r ${src_dir}/* $test
  cat $lm_dir/items.${lm_suffix} | while read item; do
    cat $lm_dir/lm_${lm_suffix}/lm_${lm_suffix}.${item} | \
      arpa2fst --disambig-symbol=#0 \
               --read-symbol-table=$test/words.txt - $test/G.fst/G.fst.${item}
  done
  # utils/validate_lang.pl --skip-determinization-check $test || exit 1;
  cp $lm_dir/items.${lm_suffix} $test/items
done

echo "Succeeded in formatting data."

exit 0
