# syntax=docker/dockerfile:1

ARG OPENSSL_1_1_VERSION=1.1.1q
ARG OPENSSL_1_1_DIR=/opt/openssl-${OPENSSL_1_1_VERSION}

#################### Build Stage 1 ####################

FROM dde AS builder

RUN <<EOT bash
  apt update
  apt --yes upgrade
  apt --yes install build-essential
EOT

# Install openssl 1.1.1 from source
# https://deanpcmad.com/2022/installing-older-ruby-versions-on-ubuntu-22-04/
ARG OPENSSL_1_1_VERSION
ARG OPENSSL_1_1_DIR

WORKDIR /tmp
RUN <<EOT bash
  curl -LO "https://www.openssl.org/source/openssl-${OPENSSL_1_1_VERSION}.tar.gz"
  tar zxvf openssl-${OPENSSL_1_1_VERSION}.tar.gz
EOT

WORKDIR openssl-${OPENSSL_1_1_VERSION}
RUN <<EOT bash
  ./config --prefix=${OPENSSL_1_1_DIR} --openssldir=${OPENSSL_1_1_DIR}
  make
  make test
EOT

# `RUN make install` will also install man pages and html docs, which we don't need
# We'll cherry pick the targets we want from the install target.
# install: install_sw install_ssldirs install_docs
RUN <<EOT bash
  make install_sw
  make install_ssldirs
EOT

# Download and install ruby-install
ARG RUBY_INSTALL_VERSION=0.8.5

WORKDIR /tmp
RUN <<EOT bash
  curl -L "https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VERSION}.tar.gz" > "ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
  tar -xzvf ruby-install-${RUBY_INSTALL_VERSION}.tar.gz
EOT

WORKDIR /tmp/ruby-install-${RUBY_INSTALL_VERSION}/
RUN make install

# Download and install chruby
ARG CHRUBY_VERSION=0.3.9

WORKDIR /tmp
RUN <<EOT bash
  curl -L "https://github.com/postmodern/chruby/archive/v${CHRUBY_VERSION}.tar.gz" > "chruby-${CHRUBY_VERSION}.tar.gz"
  tar -zxvf "/tmp/chruby-${CHRUBY_VERSION}.tar.gz"
EOT

WORKDIR /tmp/chruby-${CHRUBY_VERSION}/
RUN make install

# Install some Rubies
RUN <<EOT bash
  ruby-install ruby 2.7.1 -- --with-openssl-dir="${OPENSSL_1_1_DIR}"
  #ruby-install ruby 2.7.6 -- --with-openssl-dir="${OPENSSL_1_1_DIR}"

  # 3.1.2 builds against OpenSSL 3.0.2
  ruby-install ruby 3.1.2
EOT

#################### Build Stage 2 ####################

FROM dde

RUN <<EOT bash
  apt update
  apt --yes upgrade
EOT

MAINTAINER blitterated blitterated@protonmail.com

# Some older ruby versions have trouble if $HOME is not set
ENV HOME=/root

# We'll be running as root in the docker container
ENV BUNDLE_SILENCE_ROOT_WARNING=1

# Copy chruby
COPY --from=builder /usr/local/share/chruby /usr/local/share/chruby
COPY --from=builder /usr/local/bin/chruby-exec /usr/local/bin/chruby-exec

# Copy ruby-install
COPY --from=builder /usr/local/share/ruby-install /usr/local/share/ruby-install
COPY --from=builder /usr/local/bin/ruby-install /usr/local/bin/ruby-install

# This copies the rubies and the old openssl
COPY --from=builder /opt /opt

# Create a soft link to OpenSSL 3 certs for 1.1.1
RUN <<EOT bash
  rm -rf ${OPENSSL_1_1_DIR}/certs
  ln -s /etc/ssl/certs ${OPENSSL_1_1_DIR}/certs
EOT

WORKDIR /root

COPY shell/003-chruby-activation.sh .dde.rc/003-chruby-activation.sh
