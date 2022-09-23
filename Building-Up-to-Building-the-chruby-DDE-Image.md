## Initial Ideas

The need for a chruby image was originally a need for a MiddleMan image. I have an older  code base that uses Ruby 2.7.1 and MiddleMan. I didn't want to pollute my machine with old Ruby versions or `chruby` which adds a lot of time to shell start up with setup calls in `.bashrc`

After attempting to build the MiddleMan image, it quickly became apparent that I needed to separate out Ruby and chruby into their own image first. Then I could build a MiddleMan image on top of that. It worked out well because getting `ruby` to build on Ubuntu 22.04 is a real pain. Ubuntu 22.04 only supplies OpenSSL 3.x packages, but Rubies in the 2.7 versions require OpenSSL version 1.1.1 or earlier in order to build with `ruby-install`.

This is a recounting based on a crib sheet I kept as I manually built my first image.

## The Trickier Parts

### Docker Image for MiddleMan Catch 22 #1
MiddleMan is a gem just like any other dependency you would install. 
It will be in the Gemfile of whatever project you pull down.
How to you setup MiddleMan as a DDE service on an image, when you haven't yet run the image against you source and bundle installed the gems?
A special command like with `hrun new` and the HugoDDE.

### Docker Image for MiddleMan Catch 22 #2:
We want the same version of ruby running for the middleman server as what's specified in the project's .ruby_version file
Set it up in the run file with:
  `source /usr/local/share/chruby/chruby.sh` and
  `chruby $(cat /blog/.ruby-version)`  # what to do if trying to create a new site?
This requires the run file to be written in bash, since the chruby command is actually a bash function.
abfi

## The Plan

Build a chruby docker image based on DDE

- install ruby 2.7.1
- install bundle

Build a MiddleMan docker image based on chruby-dde

- install npm
- bundle install project deps including MiddleMan

Create a mmrun script

- mmrun install-deps
  - bundle install
  - npm install
- mmrum [start]

Some additional, nebulous, floaty ideas:

- Install deps from source dir
- Run image against source dir
- `run` needs `blog/` specified
- `finish` needs work

## Manually Build a chruby-dde Image on the base DDE Image

I read [Installing Ruby with ruby-build and ruby-install](https://nts.strzibny.name/ruby-build-and-ruby-install/). It's a good article that helps with choosing between `ruby-build` and `ruby-install`.

#### Start a basic DDE container

```sh
docker run -it --rm dde /bin/bash
```

#### Get packages updated and installed

```sh
apt update
apt --yes upgrade
apt --yes install build-essential
```

#### Download and install `chruby`

```sh
cd /tmp
CHRUBY_VERSION=0.3.9
curl -L "https://github.com/postmodern/chruby/archive/v${CHRUBY_VERSION}.tar.gz" > "chruby-${CHRUBY_VERSION}.tar.gz"
tar -zxvf "/tmp/chruby-${CHRUBY_VERSION}.tar.gz"
cd chruby-${CHRUBY_VERSION}/
make install
```

#### Download and install `ruby-install`

```sh
cd /tmp
RUBY_INSTALL_VERSION=0.8.5
curl -L "https://github.com/postmodern/ruby-install/archive/v${RUBY_INSTALL_VERSION}.tar.gz" > "ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
tar -xzvf ruby-install-${RUBY_INSTALL_VERSION}.tar.gz
cd ruby-install-${RUBY_INSTALL_VERSION}/
make install
```

`ruby-install` will fail to build `ruby` unless OpenSSL is version 1.1.x or lower.

ubuntu jammy only supplies OpenSSL 3, and it comes installed by default.

```text 
root@f559a37fa63e:/tmp# apt list -a openssl
Listing... Done
openssl/jammy-updates,jammy-security 3.0.2-0ubuntu1.6 amd64
openssl/jammy 3.0.2-0ubuntu1 amd64
```

At first I uninstalled OpenSSL 3, but I wound up needing the certs that came with it for OpenSSL 1.1.1 later on. I left it in place after that. As long as `ruby` is built against OpenSSL 1.1.1 it's fine to have both installed.

#### Install OpenSSL 1.1.1 from source

I found a lot of good info on [Installing Older Ruby Versions on Ubuntu 22.04](https://deanpcmad.com/2022/installing-older-ruby-versions-on-ubuntu-22-04/) in this article. It has good instructions for building OpenSSL from source.

```sh
OPENSSL_1_1_VERSION=1.1.1q
OPENSSL_1_1_DIR=/opt/openssl-${OPENSSL_1_1_VERSION}

cd /tmp
curl -LO "https://www.openssl.org/source/openssl-${OPENSSL_1_1_VERSION}.tar.gz"
tar zxvf openssl-${OPENSSL_1_1_VERSION}.tar.gz

cd openssl-${OPENSSL_1_1_VERSION}
./config --prefix=${OPENSSL_1_1_DIR} --openssldir=${OPENSSL_1_1_DIR}
time make
time make test
time make install
```

Here is where the OpenSSL 3 certs get linked into the OpenSSL 1.1.1 directory.

```sh
rm -rf ${OPENSSL_1_1_DIR}/certs
ln -s /etc/ssl/certs ${OPENSSL_1_1_DIR}/certs
```

Here are some make command times from above for reference.

make:

```text
real 2m21.479s    2m15.165s    
user 2m1.593s     1m55.833s    
sys  0m19.628s    0m19.124s    
```

make test:

```text
real 1m32.480s    1m37.308s
user 1m22.012s    1m23.623s
sys  0m21.267s    0m22.956s
```

make install:

```text
real 1m5.231s
user 0m57.085s
sys  0m8.222s
```

### Install some Rubies.

They'll land in `/opt/rubies` since that's the default when you're installing as `root`.

```sh
ruby-install ruby 2.7.1 -- --with-openssl-dir="${OPENSSL_1_1_DIR}"
```

```sh
ruby-install ruby 2.7.6 -- --with-openssl-dir="${OPENSSL_1_1_DIR}"
```

Install time from 2.7.6 for reference.

```text
real 4m43.459s
user 4m5.580s
sys  0m36.874s
```

Clean up `/tmp`.

```sh
rm -rf /tmp/*
```

Load `chruby()` into the shell.

```sh
source /usr/local/share/chruby/chruby.sh
```

Give `ruby` 2.7.1 a spin.

```sh
chruby 2.7.1
ruby --version
```

```text
ruby 2.7.1p83 (2020-03-31 revision a0c7c23c9c) [x86_64-linux]
```


Give `ruby` 2.7.6 a spin.

```sh
chruby 2.7.6
ruby --version
```

```text
ruby 2.7.6p219 (2022-04-12 revision c9c2245c0a) [x86_64-linux]
```

## Make an image from the running container

Leave the container running, and open another shell on the host.

Find the container's ID.

```sh
docker ps
```

```text
CONTAINER ID   IMAGE        COMMAND             CREATED       STATUS       PORTS     NAMES
9417cf998f45   dde          "/init /bin/bash"   2 hours ago   Up 2 hours             purple_nurple
```

Then `commit` it to a new image.

```sh
docker commit 9417cf998f45 chruby-dde-by-hand
```

Let's see what we've got now.

```sh
docker images chruby*
```

```text
REPOSITORY           TAG       IMAGE ID       CREATED         SIZE
chruby-dde-by-hand   latest    030e49cc82b6   2 minutes ago   1.47GB
```

Woof, 1.47GB. That's huge. Let's try the export/import trick to flatten it. We did build a ton of files in this container.

```sh
CONT_ID=$(docker create chruby-dde-by-hand)
docker export $CONT_ID | docker import - chruby-dde-by-hand-flat
docker rm $CONT_ID
```

Ok, let's take a look and see how much space was saved.

```sh
docker images chruby*
```

```text
REPOSITORY                TAG       IMAGE ID       CREATED              SIZE
chruby-dde-by-hand-flat   latest    7135ab2b8ce0   About a minute ago   1.42GB
chruby-dde-by-hand        latest    030e49cc82b6   5 minutes ago        1.47GB
```

Blerg! Not too helpful. The next step is to investigate [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/).

#### Capturing `make install` and `ruby-install` output

I need to know where things are being installed to in the first build stage, so I can copy them completely to the second build stage. To do so I used `bash` redirects and `tee`. Then I pushed the resulting log files out to the host through a bind mount.

Start a DDE container with a bind mount for capturing OpenSSL and `ruby-install` installation output.

```sh
docker run -it --rm --name ddebuilder -v "$(pwd)":/host dde /bin/bash
```

Run the steps to [Get packages updated and installed](#get-packages-updated-and-installed).

Build OpenSSL and capture the `make install` output.

Run the steps for installing [from above](#install-openssl-1.1.1-from-source), but replace the `make install` step with the following.

```sh
make install 2>&1 | tee make-install-openssl-1.1.1.txt
cp make-install-openssl-1.1.1.txt /host/
```

Do the same for `ruby-install` using steps [from above](#download-and-install-ruby-install), but replace the `make install` step with the following.

```sh
make install 2>&1 | tee make-install-ruby-install.txt
cp make-install-ruby-install.txt /host/
```

Now install a ruby with `ruby-install` and capture all of its output with `tee`.


```sh
ruby-install ruby 2.7.6 -- --with-openssl-dir="/opt/openssl-1.1.1q/" 2>&1 | tee ruby-install-2.7.6.txt
```

```sh
cp ruby-install-2.7.6.txt /host/
```

#### I Took a Peek at `/opt/` before and after installing OpenSSL 1.1.1

Before:

```text
root@4417fd0b2c9c:/tmp/openssl-1.1.1q# ls /opt
root@4417fd0b2c9c:/tmp/openssl-1.1.1q#
```

After:

```text
# post build openssl 1.1.1
root@1b8121f75914:/tmp/openssl-1.1.1q# ls /opt
openssl-1.1.1q
```







# References

* [Installing Ruby with ruby-build and ruby-install](https://nts.strzibny.name/ruby-build-and-ruby-install/)
* [GH: postmodern / ruby-install](https://github.com/postmodern/ruby-install)
* [Installing Older Ruby Versions on Ubuntu 22.04](https://deanpcmad.com/2022/installing-older-ruby-versions-on-ubuntu-22-04/)
* [Docker Docs: Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
* [ServerFault: Capturing STDERR and STDOUT to file using tee](https://serverfault.com/questions/201061/capturing-stderr-and-stdout-to-file-using-tee)
* [GH: postmodern / chruby](https://github.com/postmodern/chruby)