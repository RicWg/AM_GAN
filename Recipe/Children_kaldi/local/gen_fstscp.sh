#!/bin/bash

# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

[ -f ./path.sh ] && . ./path.sh; # source the path.

if [ $# != 2 ]; then
   echo "Usage: steps/gen_fstscp.sh [options] <graph-dir> <data-dir>"
   echo "e.g.: steps/gen_fstscp.sh exp/mono/graph_tgpr data/test_dev93"
   exit 1;
fi


graphdir=$1
data=$2

[ ! -f $data/feats.scp ] && echo "$0: no such file $data/feats.scp" && exit 1;

fstdir=`pwd`/${graphdir}/HCLG.fst
# use "|" instead of "/" in sed expressions as ${fstdir} contains "/"
grep -Po "^[a-z0-9\.]+ " $data/feats.scp | \
  sed -r "s|(\.[0-9]+\.[0-9]+) $|\1 cat ${fstdir}\/HCLG\.fst\1 \||" > $data/fst.scp || exit 1

echo "$0: successfully prepared $data/fst.scp"

exit 0;
