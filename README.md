# Roku Developer Tools Container

This is a container of basic tools for developers writing applications for [Roku](https://www.roku.com/) devices.

The idea is to have tools in a single place, separated from host system for safety.


## Requirements

All you need to use this container is a Linux operating system, [podman](https://podman.io/), and at least 500 MB of free space.
It probably works on other systems and with other container runners too, but i did not test that (you're welcome to try and let me know :).

To actually run tests or application, you need a Roku device, of course.
Container does include [`brs`](https://github.com/sjbarag/brs) BrightScript interpreter, but it is very limited and does not support most of the SceneGraph components. It's mainly for running tests of pure BrightScript parts of your application.

Roku device has to have Developer Settings enabled, as per described in documentation at https://developer.roku.com/en-gb/docs/developer-program/getting-started/developer-setup.md#step-1-set-up-your-roku-device-to-enable-developer-settings.


## Installation

You can either download prebuilt container image, or build it locally.


### Using prebuilt image

You can download signature and container image files, verify them and then load image for podman to use:

```sh
curl -o rokudev.tar.zstd.sig https://c8s.neoni.net/downloads/rokudev.tar.zstd.sig \
  && curl -o rokudev.tar.zstd https://c8s.neoni.net/downloads/rokudev.tar.zstd \
  && curl https://github.com/ahwayakchih.keys | while read key; do echo "ahwayakchih ${key}" >> ahwayakchih.keys; done \
  && cat rokudev.tar.zstd | ssh-keygen -Y verify -n file -f ahwayakchih.keys -I ahwayakchih -s rokudev.tar.zstd.sig \
  && cat rokudev.tar.zstd | podman load \
  && rm -f rokudev.tar.zstd rokudev.tar.zstd.sig ahwayakchih.keys
```

If everything goes well, you should be able to see container image available locally:

```sh
podman images | grep rokudev
```

It should output something like this:

```txt
localhost/ahwayakchih/rokudev  latest      74ccba5bd523  3 days ago    426 MB
```


### Using locally built image

To build container image locally, simply clone this project:

```sh
git clone https://github.com/ahwayakchih/roku-dev-container.git
```

Enter cloned directory:

```sh
cd roku-dev-container
```

and use `make` command:

```sh
make
```

If you already have the image, but want to rebuild it, use `make build` command instead:

```sh
make build
```

If you want to host your own build of container, you can create `make.env` file that containes something like this:

```txt
SSH_SIGN_KEY_PATH=/home/$$(id -un)/.ssh/github-sk.pub
IMAGE_UPLOAD_PATH=yourSSHName:path/to/uploaded/images/
```

After that, you can use following command (which will archive image, create signature file and `scp` them both) to upload local image to specified host:

```sh
make deploy
```


## Configuration

After container image is ready to use by podman, there's nothing else required to be done.
That said, it is simpler to use this container through an alias command. Add this command alias to your shell configuration:

```sh
alias rokudev='test "$(pwd)" = "$HOME" && echo "ERROR: It is not safe to use HOME directory for a project" >&2 || podman run --rm -it -v $(pwd):/app -e PROJECT_NAME=$(basename $(pwd)) ahwayakchih/rokudev'
```


## Usage (CLI)

**WARNING**: For clarity, following intructions and command line examples assume that `rokudev` command alias is configured.

Create an empty directory for your project:

```sh
mkdir myrokuapp
```

Now enter the new directory and run initialization command:

```sh
cd myrokuapp
rokudev init
```

This should populate directory with a default project template that includes Makefile and has tests pre-configured:

```sh
ls
```

should output something like this:

```txt
components/  config/  dev.env  fonts/  images/  Makefile  manifest  source/  tests/
```

Now, before continuing, edit `dev.env` file to let scripts know the IP address of your Roku device and developer password for it.
For example, if your Roku device is using "192.168.100.100" IP number, then something like this should be in the file:

```txt
DEPLOY_HOST=192.168.100.100
DEPLOY_PASS=s3cre7
```

After you save the changes, you can build the project and run tests:

```sh
make test
```

If you just want to sideload your app, use following command:

```sh
make deploy
```

To just switch shell to the one inside container, use following command:

```sh
make shell
```


## Acknowledgments

This container depends and builds on-top of following projects:

 1. Alpine Linux: https://alpinelinux.org
 2. node.js: https://nodejs.org
 3. n: https://github.com/tj/n
 4. node-ssdp: https://github.com/diversario/node-ssdp
 5. cheerio: https://github.com/cheeriojs/cheerio
 6. mri: https://github.com/lukeed/mri
 7. minimatch: https://github.com/isaacs/minimatch
 8. brighterscript: https://github.com/rokucommunity/brighterscript
 9. bslint: https://github.com/rokucommunity/bslint
10. rooibos: https://github.com/georgejecook/rooibos
11. roku-deploy: https://github.com/rokucommunity/roku-deploy
12. @hulu/roca: https://github.com/hulu/roca/
13. brs: https://github.com/sjbarag/brs
14. @dlenroc/roku: https://github.com/dlenroc/node-roku

Listed projects are used directly by the scripts/tools in the container.
They have their own dependencies which are also installed in the container, but not listed here.


## License

Every project this container depends on has its own license. All are open-source.

[Scripts and tools](./container/bin), and makefiles written specifically for this container are under BSD 3-clause license.