# syntax=docker/dockerfile:1

#################### Build Stage 1 ####################

FROM dde AS builder

RUN <<EOT bash -xe
  apt update
  apt --yes upgrade
  apt --yes install build-essential

  # required by pry gem
  apt --yes install libyaml-0-2
EOT

# Download and install ruby-install
ARG RUBY_INSTALL_VERSION=0.9.3

WORKDIR /tmp
RUN <<EOT bash -xe
  curl -L "https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VERSION}.tar.gz" > "ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
  tar -xzvf ruby-install-${RUBY_INSTALL_VERSION}.tar.gz
EOT

WORKDIR /tmp/ruby-install-${RUBY_INSTALL_VERSION}/
RUN <<EOT bash -xe
  make install
EOT

# Download and install chruby
ARG CHRUBY_VERSION=0.3.9

WORKDIR /tmp
RUN <<EOT bash -xe
  curl -L "https://github.com/postmodern/chruby/archive/v${CHRUBY_VERSION}.tar.gz" > "chruby-${CHRUBY_VERSION}.tar.gz"
  tar -zxvf "/tmp/chruby-${CHRUBY_VERSION}.tar.gz"
EOT

WORKDIR /tmp/chruby-${CHRUBY_VERSION}/
RUN <<EOT bash -xe
  make install
EOT

# Install Ruby and gems
RUN <<EOT bash -xe
  ruby-install ruby 3.3.0
EOT

#################### Build Stage 2 ####################

FROM dde

RUN <<EOT bash -xe
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

WORKDIR /root

COPY shell/003-chruby-activation.sh .dde.rc/003-chruby-activation.sh
