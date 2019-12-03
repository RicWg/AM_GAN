#!/bin/bash

mv /storage/Recipe/* /storage/Work/

cd /storage/Work/common
bash script.all.sh > script.all.log 2> script.all.err

cd /storage/Work/Children_kaldi
bash run.sh > run.log 2> run.err
bash run.dev.sh > run.dev.log 2> run.dev.err

cd /storage/Work/Children_kalditorch
bash run.sh > run.log 2> run.err
