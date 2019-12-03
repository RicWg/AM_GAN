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

Audios are coded with 8Kbps, 8 bit, PCM, .wav format. We train the GAN with 20 hours data, and the Li-GRU is trained with 200 hours data.


The speech enhancement dataset used in this work [(Valentini et al. 2016)](http://ssw9.net/papers/ssw9_PS2-4_Valentini-Botinhao.pdf) can be found in [Edinburgh DataShare](http://datashare.is.ed.ac.uk/handle/10283/1942). However, **the following script downloads and prepares the data for TensorFlow format**:

```
./prepare_data.sh
```

Or alternatively download the dataset, convert the wav files to 16kHz sampling and set the `noisy` and `clean` training files paths in the config file `e2e_maker.cfg` in `cfg/`. Then run the script:

```
python make_tfrecords.py --force-gen --cfg cfg/e2e_maker.cfg
```

### Training

Sample command line to train can be :

```
python main.py --init_noise_std 0. --save_path AM_GAN \
                                          --init_l1_weight 100. --batch_size 50 --g_nl prelu \
                                          --save_freq 50 --preemph 0.95 --epoch 86 --bias_deconv True \
                                          --bias_downconv True --bias_D_conv True
```

### Denoising

```
CUDA_VISIBLE_DEVICES="0" python main.py --init_noise_std 0. 
										--save_path segan_allbiased_preemph                         --batch_size 100 
										--g_nl prelu 
										--weights SEGAN-50 
										--test_wav sourcefile.wav 
										--clean_save_path clean
```


