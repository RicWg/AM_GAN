ln -snf /storage/audio audio

for section in `echo train dev test`
do
  cat /dev/null > trans.${section}.exclude
  rm -r wav_${section}
  cat trans.${section} | while read line
  do
    wav0=audio/`echo $line | grep -Po "(([0-9])|(\.))+" | sed -r "s/\./\//"`.au
    wavdir0=`dirname $wav0`
    wavfile0=`basename $wav0`
    wavdir=${wavdir0/audio/wav_${section}}
    wavchapter=`basename $wavdir0`
    wavfile=${wavchapter}.${wavfile0}
    wav=${wavdir}/${wavfile}
    mkdir -p $wavdir
    if [ -f `pwd`/${wav0} ] && [ -s `pwd`/${wav0} ]; then
      echo "generating link for "${wav}
      ln -s `pwd`/${wav0} `pwd`/${wav}
    else
      echo "no source exist for "${wav}
      echo "${line}" >> trans.${section}.exclude
    fi
  done
  echo `cat trans.${section}.exclude | wc -l`" files excluded for ${section} set due to unavailability"
  grep -Fxv -f trans.${section}.exclude trans.${section} > trans.${section}.inuse
done
