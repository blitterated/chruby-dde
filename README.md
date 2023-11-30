## Usage

### Build an image

Log files will be written to the `build-logs` directory.

```sh
./build-with-log
```

### Run the image

```sh
docker run -it --rm --name chrubydde chruby-dde
```

__NOTE:__ if you try to run the above with `/bin/bash` appended, you'll get this error:

```text
/bin/bash: /bin/bash: cannot execute binary file
```

That's because this image is based on the [`dde`](https://github.com/blitterated/docker-dev-env/tree/master) image which has `/bin/bash` as its [`ENTRYPOINT`](https://github.com/blitterated/docker-dev-env/blob/master/Dockerfile#L16).

### Run a ruby

```sh
chruby 3.1.2
ruby --version
```

``` text
ruby 3.1.2p20 (2022-04-12 revision 4491bb740a) [aarch64-linux]
```
