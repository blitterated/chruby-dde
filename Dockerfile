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
RUN make install

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

CMD ["/usr/bin/env", "bash"]
