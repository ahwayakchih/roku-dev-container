-include .env

ifeq (${ROKU_ENV},)
	ROKU_ENV_IS_MISSING=yes
	ROKU_ENV=dev
endif

-include ${ROKU_ENV}.env

NOW:=$(shell date +%Y%m%dT%H%M%S)
VERSION:=$(shell export $$(cat manifest | grep _version=) && echo "$${major_version}.$${minor_version}.$${build_version}")

APP_DIR?=./

BUILDS_DIR?=${APP_DIR}/builds
CHANNEL_ZIP?=${BUILDS_DIR}/roku-v${VERSION}-${ROKU_ENV}-${NOW}.zip

define get_targeted_roku_devices
	$(shell find . -type f -name '${ROKU_ENV}*.env'\
		| while IFS= read -r line ; do\
			DEPLOY_HOST=;\
			DEPLOY_PASS=;\
			. $${line}\
				&& test -n "$${DEPLOY_HOST}"\
				&& test -n "$${DEPLOY_PASS}"\
				&& echo -n "$${line} ";\
		done)
endef
ROKUS?=$(get_targeted_roku_devices)

all: build

info:
	@echo 'Running inside container.'
	@echo "Found $(words ${ROKUS}) Roku targets in '${ROKU_ENV}' namespace"
	@test "${ROKU_ENV_IS_MISSING}" != "yes" || echo "To change namespace, set value of ROKU_ENV to desired name"

init: $(BUILDS_DIR)
	@init

build: info init
	@build --project config/bsconfig-${ROKU_ENV}.json --channel="${CHANNEL_ZIP}"
	@echo "Build of v${VERSION} done"

deploy: build $(patsubst %.env,%_deploy.env,$(ROKUS))
	@echo "Deployment done"

testOnHost:
	@roca

testOnRokus: $(patsubst %.env,%_test.env,$(ROKUS))

test: info testOnHost testOnRokus
	@echo "Everything is OK on v${VERSION}"

shell:
	@echo "You're already in the Roku dev shell"

upgrade: info
	@upgrade

clean: info
	@cleanup

# Prepare builds directory
$(BUILDS_DIR):
	@mkdir -p "${BUILDS_DIR}"

# Deploy to each available Roku device
%_deploy.env:
	@echo "Installing v${VERSION} to" $(patsubst %_deploy.env,%.env,$@)
	@. $(patsubst %_deploy.env,%.env,$@) && deploy --host="$${DEPLOY_HOST}" --password="$${DEPLOY_PASS}" --channel="${CHANNEL_ZIP}"

%_test.env:
	@echo "Testing v${VERSION} on" $(patsubst %_test.env,%.env,$@)
	@. $(patsubst %_test.env,%.env,$@) && bsc --project="${APP_DIR}/config/bsconfig-test.json" --outFile="$(patsubst %.zip,%-test.zip,${CHANNEL_ZIP})" --source-map --host="$${DEPLOY_HOST}" --password="$${DEPLOY_PASS}" || true


# Mark targets that do not create files, and should be run everytime they are mentioned
.PHONY: all info init build deploy testOnHost testOnRokus test shell upgrade clean
