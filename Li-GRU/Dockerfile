FROM pytorch/pytorch:1.1.0-cuda10.0-cudnn7.5-runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        lsb-core \
        aptitude \
        apt-file \
        apt-rdepends \
        build-essential \
        autoconf \
        automake \
        libtool \
        bzip2 \
        unzip \
        wget \
        sox \
        git \
        gawk \
        subversion \
        zlib1g-dev \
        ca-certificates \
        patch \
        vim && \
    rm -rf /var/lib/apt/lists/*

RUN ln -s /opt/conda/bin/pip /usr/local/bin/pip3 && \
    pip3 install -U \
        virtualenv \
        cmake \
        future \
        six \
        numpy \
        mkl \
        mkl-include \
        nara-wpe \
        matplotlib \
        scipy \
        blockdiag && \
    pip3 install --ignore-installed pyyaml

RUN mkdir -p /storage/
COPY Applications /storage/Applications
COPY Recipe /storage/Recipe
COPY run.recipe.sh /storage/run.recipe.sh

RUN cd /storage/Applications/kaldi-5.x && \
    for ptc in `ls patch.*`; do patch -Np0 -i $ptc; done && \
    cd /storage/Applications/kaldi-5.x/tools && \
    bash extras/install_irstlm.sh && \
    make -j $(nproc)

RUN cd /storage/Applications/kaldi-5.x/src && \
    ./configure --shared --mathlib=MKL --mkl-root=/opt/conda --mkl-libdir=/opt/conda/lib && \
    make depend -j $(nproc) && \
    make -j $(nproc)

WORKDIR /storage/
