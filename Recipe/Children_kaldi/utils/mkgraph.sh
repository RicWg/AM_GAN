#!/bin/bash
# Copyright 2010-2012 Microsoft Corporation
#           2012-2013 Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

# This script creates a fully expanded decoding graph (HCLG) that represents
# all the language-model, pronunciation dictionary (lexicon), context-dependency,
# and HMM structure in our model.  The output is a Finite State Transducer
# that has word-ids on the output, and pdf-ids on the input (these are indexes
# that resolve to Gaussian Mixture Models).
# See
#  http://kaldi-asr.org/doc/graph_recipe_test.html
# (this is compiled from this repository using Doxygen,
# the source for this part is in src/doc/graph_recipe_test.dox)

set -o pipefail

tscale=1.0
loopscale=0.1

remove_oov=false

for x in `seq 4`; do
  [ "$1" == "--mono" -o "$1" == "--left-biphone" -o "$1" == "--quinphone" ] && shift && \
    echo "WARNING: the --mono, --left-biphone and --quinphone options are now deprecated and ignored."
  [ "$1" == "--remove-oov" ] && remove_oov=true && shift;
  [ "$1" == "--transition-scale" ] && tscale=$2 && shift 2;
  [ "$1" == "--self-loop-scale" ] && loopscale=$2 && shift 2;
done

if [ $# != 3 ]; then
   echo "Usage: utils/mkgraph.sh [options] <lang-dir> <model-dir> <graphdir>"
   echo "e.g.: utils/mkgraph.sh data/lang_test exp/tri1/ exp/tri1/graph"
   echo " Options:"
   echo " --remove-oov       #  If true, any paths containing the OOV symbol (obtained from oov.int"
   echo "                    #  in the lang directory) are removed from the G.fst during compilation."
   echo " --transition-scale #  Scaling factor on transition probabilities."
   echo " --self-loop-scale  #  Please see: http://kaldi-asr.org/doc/hmm.html#hmm_scale."
   echo "Note: the --mono, --left-biphone and --quinphone options are now deprecated"
   echo "and will be ignored."
   exit 1;
fi

if [ -f path.sh ]; then . ./path.sh; fi

lang=$1
tree=$2/tree
model=$2/final.mdl
dir=$3

mkdir -p $dir

# If $lang/tmp/LG.fst does not exist or is older than its sources, make it...
# (note: the [[ ]] brackets make the || type operators work (inside [ ], we
# would have to use -o instead),  -f means file exists, and -ot means older than).

required="$lang/L.fst $lang/G.fst $lang/phones.txt $lang/words.txt $lang/phones/silence.csl $lang/phones/disambig.int $model $tree"
for f in $required; do
  [ ! -e $f ] && echo "mkgraph.sh: expected $f to exist" && exit 1;
done


N=$(tree-info $tree | grep "context-width" | cut -d' ' -f2) || { echo "Error when getting context-width"; exit 1; }
P=$(tree-info $tree | grep "central-position" | cut -d' ' -f2) || { echo "Error when getting central-position"; exit 1; }

[[ -f $2/frame_subsampling_factor && "$loopscale" == "0.1" ]] && \
  echo "$0: WARNING: chain models need '--self-loop-scale 1.0'";

if [ -f $lang/phones/nonterm_phones_offset.int ]; then
  if [[ $N != 2  || $P != 1 ]]; then
    echo "$0: when doing grammar decoding, you can only build graphs for left-biphone trees."
    exit 1
  fi
  nonterm_phones_offset=$(cat $lang/phones/nonterm_phones_offset.int)
  nonterm_opt="--nonterm-phones-offset=$nonterm_phones_offset"
  prepare_grammar_command="make-grammar-fst --nonterm-phones-offset=$nonterm_phones_offset - -"
else
  prepare_grammar_command="cat"
  nonterm_opt=
fi

mkdir -p $lang/tmp/LG.fst $lang/tmp/CLG_${N}_${P}.fst \
  $lang/tmp/ilabels_${N}_${P} $lang/tmp/disambig_ilabels_${N}_${P}.int \
  $dir/Ha.fst $dir/HCLGa.fst $dir/disambig_tid.int $dir/HCLG.fst
cat $lang/items | while read item; do

trap "rm -f $lang/tmp/LG.fst/LG.fst.${item}.$$" EXIT HUP INT PIPE TERM
# Note: [[ ]] is like [ ] but enables certain extra constructs, e.g. || in
# place of -o
if [[ ! -s $lang/tmp/LG.fst/LG.fst.${item} || \
      $lang/tmp/LG.fst/LG.fst.${item} -ot $lang/G.fst/G.fst.${item} || \
      $lang/tmp/LG.fst/LG.fst.${item} -ot $lang/L_disambig.fst ]]; then
  fsttablecompose $lang/L_disambig.fst $lang/G.fst/G.fst.${item} | \
    fstdeterminizestar --use-log=true | \
    fstminimizeencoded | fstpushspecial > $lang/tmp/LG.fst/LG.fst.${item}.$$ || exit 1;
  mv $lang/tmp/LG.fst/LG.fst.${item}.$$ $lang/tmp/LG.fst/LG.fst.${item}
  fstisstochastic $lang/tmp/LG.fst/LG.fst.${item} || echo "[info]: LG not stochastic."
fi

clg=$lang/tmp/CLG_${N}_${P}.fst/CLG_${N}_${P}.fst.${item}
clg_tmp=$clg.$$
ilabels=$lang/tmp/ilabels_${N}_${P}/ilabels_${N}_${P}.${item}
ilabels_tmp=$ilabels.$$
trap "rm -f $clg_tmp $ilabels_tmp" EXIT HUP INT PIPE TERM
if [[ ! -s $clg || $clg -ot $lang/tmp/LG.fst/LG.fst.${item} \
    || ! -s $ilabels || $ilabels -ot $lang/tmp/LG.fst/LG.fst.${item} ]]; then
  fstcomposecontext $nonterm_opt --context-size=$N --central-position=$P \
   --read-disambig-syms=$lang/phones/disambig.int \
   --write-disambig-syms=$lang/tmp/disambig_ilabels_${N}_${P}.int/disambig_ilabels_${N}_${P}.int.${item} \
    $ilabels_tmp $lang/tmp/LG.fst/LG.fst.${item} |\
    fstarcsort --sort_type=ilabel > $clg_tmp
  mv $clg_tmp $clg
  mv $ilabels_tmp $ilabels
  fstisstochastic $clg || echo "[info]: CLG not stochastic."
fi

trap "rm -f $dir/Ha.fst/Ha.fst.${item}.$$" EXIT HUP INT PIPE TERM
if [[ ! -s $dir/Ha.fst/Ha.fst.${item} || $dir/Ha.fst/Ha.fst.${item} -ot $model  \
    || $dir/Ha.fst/Ha.fst.${item} -ot $lang/tmp/ilabels_${N}_${P}/ilabels_${N}_${P}.${item} ]]; then
  make-h-transducer $nonterm_opt --disambig-syms-out=$dir/disambig_tid.int/disambig_tid.int.${item} \
    --transition-scale=$tscale $lang/tmp/ilabels_${N}_${P}/ilabels_${N}_${P}.${item} $tree $model \
     > $dir/Ha.fst/Ha.fst.${item}.$$  || exit 1;
  mv $dir/Ha.fst/Ha.fst.${item}.$$ $dir/Ha.fst/Ha.fst.${item}
fi

trap "rm -f $dir/HCLGa.fst/HCLGa.fst.${item}.$$" EXIT HUP INT PIPE TERM
if [[ ! -s $dir/HCLGa.fst/HCLGa.fst.${item} || \
      $dir/HCLGa.fst/HCLGa.fst.${item} -ot $dir/Ha.fst/Ha.fst.${item} || \
      $dir/HCLGa.fst/HCLGa.fst.${item} -ot $clg ]]; then
  if $remove_oov; then
    [ ! -f $lang/oov.int ] && \
      echo "$0: --remove-oov option: no file $lang/oov.int" && exit 1;
    clg="fstrmsymbols --remove-arcs=true --apply-to-output=true $lang/oov.int $clg|"
  fi
  fsttablecompose $dir/Ha.fst/Ha.fst.${item} "$clg" | fstdeterminizestar --use-log=true \
    | fstrmsymbols $dir/disambig_tid.int/disambig_tid.int.${item} | fstrmepslocal | \
     fstminimizeencoded > $dir/HCLGa.fst/HCLGa.fst.${item}.$$ || exit 1;
  mv $dir/HCLGa.fst/HCLGa.fst.${item}.$$ $dir/HCLGa.fst/HCLGa.fst.${item}
  fstisstochastic $dir/HCLGa.fst/HCLGa.fst.${item} || echo "HCLGa is not stochastic"
fi

trap "rm -f $dir/HCLG.fst/HCLG.fst.${item}.$$" EXIT HUP INT PIPE TERM
if [[ ! -s $dir/HCLG.fst/HCLG.fst.${item} || \
      $dir/HCLG.fst/HCLG.fst.${item} -ot $dir/HCLGa.fst/HCLGa.fst.${item} ]]; then
  add-self-loops --self-loop-scale=$loopscale --reorder=true $model $dir/HCLGa.fst/HCLGa.fst.${item} | \
    $prepare_grammar_command > $dir/HCLG.fst/HCLG.fst.${item}.$$ || exit 1;
  mv $dir/HCLG.fst/HCLG.fst.${item}.$$ $dir/HCLG.fst/HCLG.fst.${item}
  if [ $tscale == 1.0 -a $loopscale == 1.0 ]; then
    # No point doing this test if transition-scale not 1, as it is bound to fail.
    fstisstochastic $dir/HCLG.fst/HCLG.fst.${item} || echo "[info]: final HCLG is not stochastic."
  fi
fi

# note: the empty FST has 66 bytes.  this check is for whether the final FST
# is the empty file or is the empty FST.
if ! [ $(head -c 67 $dir/HCLG.fst/HCLG.fst.${item} | wc -c) -eq 67 ]; then
  echo "$0: it looks like the result in $dir/HCLG.fst is empty"
  exit 1
fi

done

# save space.
rm -r $dir/HCLGa.fst $dir/Ha.fst 2>/dev/null || true

# keep a copy of the lexicon and a list of silence phones with HCLG...
# this means we can decode without reference to the $lang directory.


cp $lang/words.txt $dir/ || exit 1;
mkdir -p $dir/phones
cp $lang/phones/word_boundary.* $dir/phones/ 2>/dev/null # might be needed for ctm scoring,
cp $lang/phones/align_lexicon.* $dir/phones/ 2>/dev/null # might be needed for ctm scoring,
cp $lang/phones/optional_silence.* $dir/phones/ 2>/dev/null # might be needed for analyzing alignments.
    # but ignore the error if it's not there.


cp $lang/phones/disambig.{txt,int} $dir/phones/ 2> /dev/null
cp $lang/phones/silence.csl $dir/phones/ || exit 1;
cp $lang/phones.txt $dir/ 2> /dev/null # ignore the error if it's not there.

am-info --print-args=false $model | grep pdfs | awk '{print $NF}' > $dir/num_pdfs
