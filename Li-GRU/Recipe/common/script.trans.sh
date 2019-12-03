head -n 14468 data.220 > data.25
head -n 1111 data.test1 > data.test0
#grep -Fo -f data.test1 data.ac1 |\
#  grep -Pv "(\#)|(\()|(\))|(\-)|(\~)" |\
#  head -n 120 \
#  > data.test0

ln -sf data.930 data.am # modify this one to use data.{25,220,930} for AM
ln -sf data.930 data.lm # modify this one to use data.{25,220,930} for LM
ln -sf data.test1 data.test # modify this one to use data.test{0,1} for decoding
grep -Fxv -f data.test1 data.am > data.traindev
grep -Fxv -f data.test1 data.lm > data.trainlm

cat data.traindev |\
  grep -Pv "(\()|(\))|(\-)|(\~)" |\
  sed -r -e "s/.*/\U&/" -e "s/\//\./1" -e "s/\, +/ /" |\
  sort -R --random-source=/dev/zero \
  > trans.traindev
cat data.trainlm |\
  grep -Pv "(\()|(\))|(\-)|(\~)" |\
  sed -r -e "s/.*/\U&/" -e "s/\//\./1" -e "s/\, +/ /" |\
  sort -R --random-source=/dev/zero \
  > trans.trainlm
cat data.test |\
  grep -Pv "^$" |\
  sed -r -e "s/.*/\U&/" -e "s/\//\./1" -e "s/\, +/ /" |\
  sort -R --random-source=/dev/zero \
  > trans.test

head -n -2222 trans.traindev > trans.train
tail -n 2222 trans.traindev > trans.dev
