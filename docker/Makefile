SYSTEM = $(shell uname -s)
DOCKER_IMAGE = blockscout_prod
BS_CONTAINER_NAME = blockscout
THIS_FILE = $(lastword $(MAKEFILE_LIST))

DB_URL = postgresql://$(DB_USER):$(DB_PASS)@$(DB_HOST)/$(DB_NAME)?ssl=true

BLOCKSCOUT_CONTAINNER_PARAMS = -e 'MIX_ENV=prod' \
															 -e 'DATABASE_URL=$(DB_URL)'
ifeq ($(SYSTEM), Linux)
	BLOCKSCOUT_CONTAINNER_PARAMS += --network=host
endif
ifdef ETHEREUM_JSONRPC_VARIANT
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'ETHEREUM_JSONRPC_VARIANT=$(ETHEREUM_JSONRPC_VARIANT)'
endif
ifdef ETHEREUM_JSONRPC_HTTP_URL
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'ETHEREUM_JSONRPC_HTTP_URL=$(ETHEREUM_JSONRPC_HTTP_URL)'
endif
ifdef ETHEREUM_JSONRPC_WS_URL
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'ETHEREUM_JSONRPC_WS_URL=$(ETHEREUM_JSONRPC_WS_URL)'
endif
ifdef ETHEREUM_JSONRPC_TRACE_URL
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'ETHEREUM_JSONRPC_TRACE_URL=$(ETHEREUM_JSONRPC_TRACE_URL)'
endif
ifdef COIN
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'COIN=$(COIN)'
endif
ifdef LOGO
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'LOGO=$(LOGO)'
endif
ifdef NETWORK
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'NETWORK=$(NETWORK)'
endif
ifdef SUBNETWORK
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'SUBNETWORK=$(SUBNETWORK)'
endif
ifdef NETWORK_ICON
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'NETWORK_ICON=$(NETWORK_ICON)'
endif
ifdef NETWORK_PATH
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'NETWORK_PATH=$(NETWORK_PATH)'
endif

HAS_BLOCKSCOUT_IMAGE := $(shell docker images | grep ${DOCKER_IMAGE})

build:
	@echo "==> Database URL $(DB_URL)"
	@echo "==> Checking for blockscout image $(DOCKER_IMAGE)"
ifdef HAS_BLOCKSCOUT_IMAGE
	@echo "==> Image exist. Using $(DOCKER_IMAGE)"
else
	@echo "==> No image found trying to build one..."
	@docker build --build-arg COIN="$(COIN)" -f ./Dockerfile -t $(DOCKER_IMAGE) ../
endif

migrate: build
	@echo "==> Running migrations"
	@docker run --rm \
					$(BLOCKSCOUT_CONTAINNER_PARAMS) \
					$(DOCKER_IMAGE) /bin/sh -c "echo $$MIX_ENV && mix do ecto.drop --force, ecto.create, ecto.migrate"

start: build
	@echo "==> Starting blockscout"
	@docker run \
					--detach \
					--rm \
					--name $(BS_CONTAINER_NAME) \
					$(BLOCKSCOUT_CONTAINNER_PARAMS) \
					-p 4000:4000 \
					--restart=on-failure \
					$(DOCKER_IMAGE) \
					/bin/sh -c "mix phx.server"

run: start

.PHONY: build \
				migrate \
				start \
				run
