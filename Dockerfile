# Build Stage #1

FROM dde AS builder

RUN apt update
RUN apt --yes upgrade
RUN apt --yes install build-essential

# Install openssl 1.1.1 from source
# https://deanpcmad.com/2022/installing-older-ruby-versions-on-ubuntu-22-04/
ARG OPENSSL_1_1_VERSION=1.1.1q
ARG OPENSSL_1_1_DIR=/opt/openssl-${OPENSSL_1_1_VERSION}

WORKDIR /tmp
RUN curl -LO "https://www.openssl.org/source/openssl-${OPENSSL_1_1_VERSION}.tar.gz"
RUN tar zxvf openssl-${OPENSSL_1_1_VERSION}.tar.gz

WORKDIR openssl-${OPENSSL_1_1_VERSION}
RUN ./config --prefix=${OPENSSL_1_1_DIR} --openssldir=${OPENSSL_1_1_DIR}
RUN make
RUN make test

# `RUN make install` will also install man pages and html docs, which we don't need
# We'll cherry pick the targets we want from the install target.
# install: install_sw install_ssldirs install_docs
RUN make install_sw
RUN make install_ssldirs

# Download and install ruby-install
ARG RUBY_INSTALL_VERSION=0.8.5

WORKDIR /tmp
RUN curl -L "https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VERSION}.tar.gz" > "ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
RUN tar -xzvf ruby-install-${RUBY_INSTALL_VERSION}.tar.gz

WORKDIR /tmp/ruby-install-${RUBY_INSTALL_VERSION}/
RUN make install

# Download and install chruby
ARG CHRUBY_VERSION=0.3.9

WORKDIR /tmp
RUN curl -L "https://github.com/postmodern/chruby/archive/v${CHRUBY_VERSION}.tar.gz" > "chruby-${CHRUBY_VERSION}.tar.gz"
RUN tar -zxvf "/tmp/chruby-${CHRUBY_VERSION}.tar.gz"

WORKDIR /tmp/chruby-${CHRUBY_VERSION}/
RUN make install

# Install some Rubies
RUN ruby-install ruby 2.7.1 -- --with-openssl-dir="${OPENSSL_1_1_DIR}"
RUN ruby-install ruby 2.7.6 -- --with-openssl-dir="${OPENSSL_1_1_DIR}"

# 3.1.2 builds against OpenSSL 3.0.2
RUN ruby-install ruby 3.1.2


# Build Stage #2

#FROM dde

#RUN apt update
#RUN apt --yes upgrade
#RUN apt --yes install build-essential

#MAINTAINER blitterated blitterated@protonmail.com

# Some older ruby version have trouble if $HOME is not set
ENV HOME=/root

# We'll be running as root in the docker container
ENV BUNDLE_SILENCE_ROOT_WARNING=1







# Create a soft link to OpenSSL 3 certs for 1.1.1
RUN rm -rf ${OPENSSL_1_1_DIR}/certs
RUN ln -s /etc/ssl/certs ${OPENSSL_1_1_DIR}/certs

WORKDIR /root

COPY shell/002-chruby-activation.sh .dde.rc/002-chruby-activation.sh

CMD ["/usr/bin/env", "bash"]
