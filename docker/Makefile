SYSTEM = $(shell uname -s)
HOST = host.docker.internal
DOCKER_IMAGE = blockscout_prod
PG_CONTAINER_NAME = postgres
PG_CONTAINER_IMAGE = postgres:10.4
THIS_FILE = $(lastword $(MAKEFILE_LIST))

ifeq ($(SYSTEM), Linux)
	HOST=localhost
endif

DB_URL = postgresql://postgres:@$(HOST):5432/explorer?ssl=false
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
ifdef ETHEREUM_JSONRPC_WEB_SOCKET_URL
	BLOCKSCOUT_CONTAINNER_PARAMS += -e 'ETHEREUM_JSONRPC_WEB_SOCKET_URL=$(ETHEREUM_JSONRPC_WEB_SOCKET_URL)'
endif

HAS_BLOCKSCOUT_IMAGE := $(shell docker images | grep ${DOCKER_IMAGE})
build: 
	@echo "==> Checking for blockscout image $(DOCKER_IMAGE)"
ifdef HAS_BLOCKSCOUT_IMAGE
	@echo "==> Image exist. Using $(DOCKER_IMAGE)"
else
	@echo "==> No image found trying to build one..."
	@docker build -f ./Dockerfile -t $(DOCKER_IMAGE) ../
endif

migrate: build postgres
	@echo "==> Running migrations"
	@docker run --rm \
					$(BLOCKSCOUT_CONTAINNER_PARAMS) \
					$(DOCKER_IMAGE) /bin/sh -c "echo $$MIX_ENV && mix do ecto.drop --force, ecto.create, ecto.migrate"


PG_EXIST := $(shell docker ps -a | grep ${PG_CONTAINER_NAME})
PG_STARTED := $(shell docker ps | grep ${PG_CONTAINER_NAME})
postgres:
ifdef PG_EXIST
	@echo "==> Checking PostrgeSQL container"
ifdef PG_STARTED
	@echo "==> PostgreSQL Already started"
else
	@echo "==> Starting PostgreSQL container"
	@docker start $(PG_CONTAINER_NAME)
endif
else
	@echo "==> Creating new PostgreSQL container"
	@docker run -d --name $(PG_CONTAINER_NAME) \
					-e POSTGRES_PASSWORD="" \
					-e POSTGRES_USER="postgres" \
					-p 5432:5432 \
					$(PG_CONTAINER_IMAGE)
	@sleep 1
	@$(MAKE) -f $(THIS_FILE) migrate
endif

start: build postgres 
	@echo "==> Starting blockscout"
	@docker run --rm \
					$(BLOCKSCOUT_CONTAINNER_PARAMS) \
					-p 4000:4000 \
					$(DOCKER_IMAGE) /bin/sh -c "mix phx.server"

run: start

.PHONY: build \
				migrate \
				start \
				postgres \
				run 
