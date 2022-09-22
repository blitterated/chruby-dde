FROM dde AS builder

MAINTAINER blitterated blitterated@protonmail.com

RUN apt update
RUN apt --yes upgrade
RUN apt --yes install build-essential

# Install openssl 1.1.1 from source
# https://deanpcmad.com/2022/installing-older-ruby-versions-on-ubuntu-22-04/
ARG OPENSSL_1_1_VERSION=1.1.1q
ARG OPENSSL_1_1_DIR=/opt/openssl-${OPENSSL_1_1_VERSION}
RUN cd /tmp
RUN curl -LO "https://www.openssl.org/source/openssl-${OPENSSL_1_1_VERSION}.tar.gz"
RUN tar zxvf openssl-${OPENSSL_1_1_VERSION}.tar.gz
RUN cd openssl-${OPENSSL_1_1_VERSION}
RUN ./config --prefix=${OPENSSL_1_1_DIR} --openssldir=${OPENSSL_1_1_DIR}
RUN make
RUN make test
RUN make install
#RUN rm -rf ${OPENSSL_1_1_DIR}/certs
#RUN ln -s /etc/ssl/certs ${OPENSSL_1_1_DIR}/certs

# Download and install ruby-install
#ARG RUBY_INSTALL_VERSION=0.8.5
#RUN cd /tmp
#RUN curl -L "https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VERSION}.tar.gz" > "ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
#RUN tar -xzvf ruby-install-${RUBY_INSTALL_VERSION}.tar.gz
#RUN cd ruby-install-${RUBY_INSTALL_VERSION}/
#RUN make install


CMD ["/usr/bin/env", "bash"]
