IMAGE_NAME=ahwayakchih/roku-dev-container
IMAGE_VERSION=latest

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

ROKUSDK:=${CONTAINER_ENGINE} run --rm -it --userns=keep-id -v ./:/app -e ROKU_ENV=${ROKU_ENV} ${IMAGE_NAME}:${IMAGE_VERSION}

all: build

info: is_not_home
	@echo 'Using "'${CONTAINER_ENGINE}'" container engine, set CONTAINER_ENGINE=your_engine_of_choice to override that'

init: info
	@${ROKUSDK} make init

build: info
	@${ROKUSDK} make build

deploy: info
	@${ROKUSDK} make deploy

test:
	@${ROKUSDK} make test

shell: info
	@${ROKUSDK} || exit 0

upgrade: info
	@${CONTAINER_ENGINE} run --name upgrade-roku-dev-container --user=root -v ./:/app ${IMAGE_NAME}:${IMAGE_VERSION} upgrade
	@${CONTAINER_ENGINE} container commit upgrade-roku-dev-container -c CMD=/bin/sh ${IMAGE_NAME}:${IMAGE_VERSION}
	@${CONTAINER_ENGINE} container rm upgrade-roku-dev-container

clean: info
	@${ROKUSDK} make clean

is_not_home:
	@(test ! -d "./.ssh" && test ! -d "./.bash_history" && test ! -d "./.bashrc" && test ! -d "./.zshrc") || test -n "${FORCE_APP_DIR}" || (\
		echo "ERROR: It is not safe to run sdk in what looks like a home directory!" >&2;\
		echo "       You can create subdirectory first and run sdk there." >&2;\
		echo "       Or set FORCE_APP_DIR=true variable in environment and then run sdk." >&2;\
		exit 1)


# Mark targets that do not create files, and should be run everytime they are mentioned
.PHONY: all info init build deploy testOnHost testOnRokus test shell upgrade clean is_not_home 
