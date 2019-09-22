FROM archlinux/base

RUN pacman -Syu git sudo fakechroot --noconfirm
RUN useradd -ms /bin/bash archer-builder
RUN echo "archer-builder ALL = NOPASSWD : ALL" >> /etc/sudoers

USER archer-builder
WORKDIR /home/archer-builder/

RUN git clone -b develop https://github.com/archer-linux/archer.git \
    && cd archer/iso-generator/ \
    && ./iso-generator.sh
CMD exit
