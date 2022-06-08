IMAGE_NAME=ahwayakchih/roku-dev-container
IMAGE_VERSION=latest
IMAGE_EXPORT_NAME=rokudev.tar.zstd

ALPINE_URL?=http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64
ALPINE_VERSION?=$(shell curl -s ${ALPINE_URL}/ | grep 'alpine-minirootfs' | grep -Eiv '_rc[0-9]+' | tail -n 1 | sed -e 's/<[^>]*>//g' | cut -d " " -s -f 1 | cut -d "-" -f 3)

ALPINE_PKG=alpine-minirootfs-${ALPINE_VERSION}-x86_64.tar.gz
ALPINE_SUM=${ALPINE_PKG}.sha512

ALPINE_MAJOR=$(shell echo ${ALPINE_VERSION} | cut -d "." -s -f 1)
ALPINE_MINOR=$(shell echo ${ALPINE_VERSION} | cut -d "." -s -f 2)

NODE_VERSION?=16.15.1

HAS_PODMAN=$(shell podman --version >/dev/null 2>&1 && echo -n "podman" || false)
HAS_DOCKER=$(shell docker --version >/dev/null 2>&1 && docker ps >/dev/null 2>&1 && echo -n "docker" || false)
ifeq (${HAS_PODMAN}${HAS_DOCKER},podmandocker)
	# Since dockerd seems to be running, we can assume that's what user wants at the moment
	CONTAINER_ENGINE?=docker
else ifeq (${HAS_PODMAN},podman)
	CONTAINER_ENGINE?=podman
else
	CONTAINER_ENGINE?=docker
endif

EXISTS:=$(shell ${CONTAINER_ENGINE} inspect ${IMAGE_NAME}:${IMAGE_VERSION} 2>/dev/null | jq -e '.[0].Created | select(. == null | not)')

# These are to be overridden by make.env file
SSH_SIGN_KEY_PATH=
IMAGE_UPLOAD_PATH=
-include make.env

ifeq (${EXISTS},)
all: build
else
all: ignore
endif

info:
	@echo 'Using "'${CONTAINER_ENGINE}'" container engine, set CONTAINER_ENGINE=your_engine_of_choice to override that'

ignore: info
	@echo ${IMAGE_NAME}':'${IMAGE_VERSION}' was built on ${EXISTS}'
	@echo 'skipping build'
	@echo 'to force (re)build, run: "make build" instead'

build: info
	@echo 'Using Alpine Linux v'${ALPINE_VERSION}
	@if [ ! -f ${ALPINE_PKG} ]; then\
		echo 'Downloading '${ALPINE_PKG};\
		curl -s ${ALPINE_URL}/${ALPINE_PKG} -o ${ALPINE_PKG};\
	fi
	@echo 'Downloading '${ALPINE_SUM}
	@curl -s ${ALPINE_URL}/${ALPINE_SUM} -o ${ALPINE_SUM}
	@echo 'Validating '${ALPINE_PKG}
	@sha512sum -c ${ALPINE_SUM}

	@echo 'Building '${IMAGE_NAME}':'${IMAGE_VERSION}'...'
	@cd container && ${CONTAINER_ENGINE} build --rm --squash-all -t ${IMAGE_NAME}:build --build-arg ALPINE=${ALPINE_PKG} --build-arg NODE_VERSION=${NODE_VERSION} .

	@if ${CONTAINER_ENGINE} image exists "${IMAGE_NAME}:${IMAGE_VERSION}" ; then\
		echo "Removing previous ${IMAGE_NAME}:${IMAGE_VERSION} image";\
		${CONTAINER_ENGINE} rmi ${IMAGE_NAME}:${IMAGE_VERSION} || true;\
	fi

	@echo 'Tagging ${IMAGE_NAME}:build as '${IMAGE_VERSION}'...'
	@${CONTAINER_ENGINE} tag ${IMAGE_NAME}:build ${IMAGE_NAME}:${IMAGE_VERSION}

	@if [ "${IMAGE_VERSION}" != "latest" ]; then\
		echo  'Tagging ${IMAGE_NAME}:build as latest...';\
		${CONTAINER_ENGINE} tag ${IMAGE_NAME}:build ${IMAGE_NAME}:latest;\
	fi

	@echo 'Removing build tag...'
	@${CONTAINER_ENGINE} rmi ${IMAGE_NAME}:build

	@if [ -f ${ALPINE_PKG} ]; then\
		echo 'Cleaning up';\
		rm ${ALPINE_PKG};\
		rm ${ALPINE_SUM};\
	fi

	@cd ..

upgrade: info
	@if ! ${CONTAINER_ENGINE} image exists "${IMAGE_NAME}:${IMAGE_VERSION}" ; then\
		echo "No ${IMAGE_NAME}:${IMAGE_VERSION} image found, run build instead.";\
	else\
		${CONTAINER_ENGINE} run --replace --name "upgrade-roku-dev" "${IMAGE_NAME}:${IMAGE_VERSION}" upgrade;\
		find ./container/bin -type f -exec ${CONTAINER_ENGINE} cp {} "upgrade-roku-dev":/usr/local/bin/ \;;\
		find ./container/assets -type f -exec ${CONTAINER_ENGINE} cp {} "upgrade-roku-dev":/usr/local/share/roku/ \;;\
		${CONTAINER_ENGINE} container commit -c CMD=/bin/sh "upgrade-roku-dev" ${IMAGE_NAME}:${IMAGE_VERSION};\
		${CONTAINER_ENGINE} container rm "upgrade-roku-dev";\
	fi

package:
	@((test -f "${IMAGE_EXPORT_NAME}" && echo "Image already exists, skipping") || ${CONTAINER_ENGINE} save ${IMAGE_NAME}:latest | zstd -19 -o "${IMAGE_EXPORT_NAME}")
	@((test -f "${IMAGE_EXPORT_NAME}.sig" && echo "Signature already exists, skipping") || test -n "${SSH_SIGN_KEY_PATH}" && ssh-keygen -Y sign -n file -f "${SSH_SIGN_KEY_PATH}" "${IMAGE_EXPORT_NAME}") || echo "Not signing, make sure SSH_SIGN_KEY_PATH is specified"

deploy: package
	test -n "${IMAGE_UPLOAD_PATH}" && scp ${IMAGE_EXPORT_NAME}* "${IMAGE_UPLOAD_PATH}" && rm ${IMAGE_EXPORT_NAME}*

.PHONY: all
