# AM_GAN

Enhancing Acoustic Model for Children with Generative Adversarial Network

### Introduction

This is the repository for enhancing Acoustic Model with Generative Adversarial Network. In this project, we invetigate to train GAN to denoise audio and then use Li-GRU model to build the acoustic model.

The generator inside the GAN is a convolutional layer based encoder-decoder, and the discriminator is a classification model to predict the audio is noisy or not.  The generator can learn to clean the noise (or add more noise) with the help of discrimiator. We built the GAN with Tensorflow. After we train the discriminator with supervised clean/noisy audios, we then train the generator to produce more audio samples.

Light Gated Recurrent Unit (Li-GRU) network is used to train the acoustic model. We use FMLLR, CMVN and 5-layer GRU layer to build the model, together with dropout and batch normalization. We use Kaldi-5 and Pytorch to implement this model. 



### Dependencies
* Kaldi 5.x
* Pytorch 2.0
* Python 2.7/3.6
* TensorFlow 0.12


### Data

The speech enhancement dataset used in this work [(Valentini et al. 2016)](http://ssw9.net/papers/ssw9_PS2-4_Valentini-Botinhao.pdf) can be found in [Edinburgh DataShare](http://datashare.is.ed.ac.uk/handle/10283/1942). However, **the following script downloads and prepares the data for TensorFlow format**:

```
./prepare_data.sh
```

Or alternatively download the dataset, convert the wav files to 16kHz sampling and set the `noisy` and `clean` training files paths in the config file `e2e_maker.cfg` in `cfg/`. Then run the script:

```
python make_tfrecords.py --force-gen --cfg cfg/e2e_maker.cfg
```

### Training

Once you have the TFRecords file created in `data/segan.tfrecords` you can simply run the training process with:

```
./train_segan.sh
```

By default this will take all the available GPUs in your system, if any. Otherwise it will just take the CPU.

**NOTE:** If you want to specify a subset of GPUs to work on, you can do so with the `CUDA_VISIBLE_DEVICES="0, 1, <etc>"` flag in the python execution within the training script. In the case of having two GPUs they'll be identified as 0 and 1, so we could just take the first GPU with: `CUDA_VISIBLE_DEVICES="0"`.

A sample of G losses is interesting to see as stated in the paper, where L1 follows a minimization with a `100` factor and the adversarial loss gets to be equilibrated with low variance:

**L1 loss (smoothing 0.5)**

![G_L1](assets/g_l1_loss.png)

**Adversarial loss (smoothing 0.5)**

![G_ADV](assets/g_adv_loss.png)

### Loading model and prediction

First, the trained weights will have to be downloaded from [here](http://veu.talp.cat/segan/release_weights/segan_v1.1.tar.gz) and uncompressed.

Then the `main.py` script has the option to process a wav file through the G network (inference mode), where the user MUST specify the trained weights file and the configuration of the trained network. In the case of the v1 SEGAN presented in the paper, the options would be:

```
CUDA_VISIBLE_DEVICES="" python main.py --init_noise_std 0. --save_path segan_v1.1 \
                                       --batch_size 100 --g_nl prelu --weights SEGAN_full \
                                       --test_wav <wav_filename> --clean_save_path <clean_save_dirpath>
```

To make things easy, there is a bash script called `clean_wav.sh` that accepts as input argument the test filename and
the save path.



