export KALDI_ROOT=/storage/Applications/kaldi-5.x
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C

for part in test; do
  grep -Po "(\.[0-9]+){2}" trans.${part} | sed -r "s/^\.//" | sort -u | sort -n > items.${part}
  rm -r trans_trainlm lm_${part}
  mkdir trans_trainlm lm_${part}
  cat items.${part} | while read item; do
    grep "$item" trans.trainlm | sed -r -e 's/^[0-9\.]+/\<s\>/' -e 's/$/ \<\/s\>/' > trans_trainlm/trans_trainlm.$item
    build-lm.sh -n 2 -b -p -i trans_trainlm/trans_trainlm.$item -o lm_${part}/lm_${part}.${item}.gz
    gunzip -c lm_${part}/lm_${part}.${item}.gz | grep -v "<s> <s>" | sed -r "s/<unk>/<UNK>/g" > lm_${part}/lm_${part}.${item}
    rm lm_${part}/lm_${part}.${item}.gz
  done
done
rm -r trans_trainlm
