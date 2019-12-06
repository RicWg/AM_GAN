#!/usr/bin/env bash

. kaldi_decoding_scripts/path.sh

# pip3 install -U matplotlib scipy blockdiag

rm -r __pycache__

python3 run_exp.py cfg/children/liGRU_fmllr.cfg # modify this one to use {MLP,liGRU,LSTM} for DNN
