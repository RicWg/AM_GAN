#!/bin/bash

# DOWNLOAD THE DATASET
mkdir -p data
pushd data
if [ ! -d clean_trainset_wav_8k ]; then
    # Clean utterances
    if [ ! -f clean_trainset_wav.zip ]; then
        echo 'DOWNLOADING CLEAN DATASET...'
        wget http://datashare.is.ed.ac.uk/bitstream/handle/10283/1942/clean_trainset_wav.zip
    fi
    if [ ! -d clean_trainset_wav ]; then
        echo 'INFLATING CLEAN TRAINSET ZIP...'
        unzip -q clean_trainset_wav.zip -d clean_trainset_wav
    fi
    if [ ! -d clean_trainset_wav_8k ]; then
        echo 'CONVERTING CLEAN WAVS TO 8K...'
        mkdir -p clean_trainset_wav_8k
        pushd clean_trainset_wav
        ls *.wav | while read name; do
            sox $name -r 8k ../clean_trainset_wav_8k/$name
        done
        popd
    fi
fi
if [ ! -d noisy_trainset_wav_8k ]; then
    # Noisy utterances
    if [ ! -f noisy_trainset_wav.zip ]; then
        echo 'DOWNLOADING NOISY DATASET...'
        wget http://datashare.is.ed.ac.uk/bitstream/handle/10283/1942/noisy_trainset_wav.zip
    fi
    if [ ! -d noisy_trainset_wav ]; then
        echo 'INFLATING NOISY TRAINSET ZIP...'
        unzip -q noisy_trainset_wav.zip -d noisy_trainset_wav
    fi
    if [ ! -d noisy_trainset_wav_8k ]; then
        echo 'CONVERTING NOISY WAVS TO 8K...'
        mkdir -p noisy_trainset_wav_8k
        pushd noisy_trainset_wav
        ls *.wav | while read name; do
            sox $name -r 8k ../noisy_trainset_wav_8k/$name
        done
        popd
    fi
fi
popd


echo 'PREPARING TRAINING DATA...'
python make_tfrecords.py --force-gen 
