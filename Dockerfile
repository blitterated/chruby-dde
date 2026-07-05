# syntax=docker/dockerfile:1

ARG OPENSSL_1_VERSION=1.1.1q
ARG OPENSSL_1_DIR=/opt/openssl-${OPENSSL_1_VERSION}
ARG USES_OPENSSL_1=no
ARG RUBY_INSTALL_VERSION=0.8.5
ARG CHRUBY_VERSION=0.3.9
ARG RUBY_VERSIONS

#################### Build Stage 1 ####################

FROM dde AS builder_openssl_1_yes

ARG OPENSSL_1_VERSION
ARG OPENSSL_1_DIR

RUN <<EOT bash -xev
  apt update
  apt --yes upgrade
  apt --yes install build-essential
EOT

# Install openssl 1.x from source
# https://deanpcmad.com/2022/installing-older-ruby-versions-on-ubuntu-22-04/
WORKDIR /tmp
RUN <<EOT bash -xev
  curl -LO "https://www.openssl.org/source/openssl-${OPENSSL_1_VERSION}.tar.gz"
  tar zxvf openssl-${OPENSSL_1_VERSION}.tar.gz
echo "grunt"
EOT

WORKDIR openssl-${OPENSSL_1_VERSION}
RUN <<EOT bash -xev
  ./config --prefix=${OPENSSL_1_DIR} --openssldir=${OPENSSL_1_DIR}
  make
  make test
echo "fart"
EOT

# `RUN make install` will also install man pages and html docs, which we don't need
# We'll cherry pick the targets we want from the install target.
# install: install_sw install_ssldirs install_docs
RUN <<EOT bash -xev
  make install_sw
  make install_ssldirs
echo "poop"
EOT

FROM dde AS builder_openssl_1_no

ARG OPENSSL_1_VERSION
ARG OPENSSL_1_DIR

RUN <<EOT bash -xev
  apt update
  apt --yes upgrade
  apt --yes install build-essential
EOT

FROM builder_openssl_1_${USES_OPENSSL_1} as builder
ARG RUBY_INSTALL_VERSION
ARG CHRUBY_VERSION

# Download and install ruby-install
WORKDIR /tmp
RUN <<EOT bash -xev
  curl -L "https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VERSION}.tar.gz" > "ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
  tar -xzvf ruby-install-${RUBY_INSTALL_VERSION}.tar.gz
EOT

WORKDIR /tmp/ruby-install-${RUBY_INSTALL_VERSION}/
RUN <<EOT bash -xev
  make install
EOT

# Download and install chruby
WORKDIR /tmp
RUN <<EOT bash -xev
  curl -L "https://github.com/postmodern/chruby/archive/v${CHRUBY_VERSION}.tar.gz" > "chruby-${CHRUBY_VERSION}.tar.gz"
  tar -zxvf "/tmp/chruby-${CHRUBY_VERSION}.tar.gz"
EOT

WORKDIR /tmp/chruby-${CHRUBY_VERSION}/
RUN <<EOT bash -xev
  make install
EOT

# Install some Rubies
RUN <<"EOT" bash -xev
  supplied_ruby_versions=($RUBY_VERSIONS)
  #echo "supplied_ruby_versions: ${supplied_ruby_versions[*]}"
  for version in "${supplied_ruby_versions[@]}"; do
    echo "Build Ruby ${version}"
    if [[ $version < 3.2.0 ]]; then
      echo "I'm old SSL Ruby: ${version}"
      #ruby-install ruby ${version} -- --with-openssl-dir="${OPENSSL_1_DIR}"
    else
      echo "I'm shiny, new SSL Ruby: ${version}"
      #ruby-install ruby ${version}
    fi
  done
EOT

#################### Build Stage 2 ####################

FROM dde
ARG RUBY_VERSIONS

RUN <<EOT bash -xev
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

# This copies the rubies as well as the old openssl, if it's been built
COPY --from=builder /opt /opt

# If needed, create a soft link to OpenSSL 3 certs for OpenSSL 1.x
RUN <<EOT bash -xev
  if [ $USES_OPENSSL_1 = 'yes']; then
    rm -rf ${OPENSSL_1_DIR}/certs
    ln -s /etc/ssl/certs ${OPENSSL_1_DIR}/certs
  fi
EOT

WORKDIR /root

COPY shell/003-chruby-activation.sh .dde.rc/003-chruby-activation.sh
