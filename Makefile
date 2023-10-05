DOCKER_REPO := blockscout
BACKEND_APP_NAME := blockscout
FRONTEND_APP_NAME := frontend
BACKEND_CONTAINER_IMAGE := $(DOCKER_REPO)/$(BACKEND_APP_NAME)
BACKEND_CONTAINER_NAME := backend
FRONTEND_CONTAINER_NAME := frontend
VISUALIZER_CONTAINER_NAME := visualizer
SIG_PROVIDER_CONTAINER_NAME := sig-provider
STATS_CONTAINER_NAME := stats
STATS_DB_CONTAINER_NAME := stats-postgres
PROXY_CONTAINER_NAME := proxy
PG_CONTAINER_NAME := postgres
RELEASE_VERSION ?= '5.2.3'

host_ip := $(shell getent hosts host.docker.internal | awk '{ print $$1 }')

start:
	@echo "==> Starting blockscout db"
	@docker-compose -f ./docker-compose/services/docker-compose-db.yml up -d
	@echo "==> Starting blockscout backend"
	@ETHEREUM_JSONRPC_HTTP_URL=http://$(host_ip):8545 ETHEREUM_JSONRPC_WS_URL=ws://$(host_ip):8545 docker-compose -f ./docker-compose/services/docker-compose-backend.yml up -d
	@echo "==> Starting stats microservice"
	@docker-compose -f ./docker-compose/services/docker-compose-stats.yml up -d
	@echo "==> Starting visualizer microservice"
	@docker-compose -f ./docker-compose/services/docker-compose-visualizer.yml up -d
	@echo "==> Starting sig-provider microservice"
	@docker-compose -f ./docker-compose/services/docker-compose-sig-provider.yml up -d
	@echo "==> Starting blockscout frontend"
	@docker-compose -f ./docker-compose/services/docker-compose-frontend.yml up -d
	@echo "==> Starting Nginx proxy"
	@docker-compose -f ./docker-compose/services/docker-compose-nginx.yml up -d

BS_BACKEND_STARTED := $(shell docker ps --no-trunc --filter name=^/${BACKEND_CONTAINER_NAME}$  | grep ${BACKEND_CONTAINER_NAME})
BS_FRONTEND_STARTED := $(shell docker ps --no-trunc --filter name=^/${FRONTEND_CONTAINER_NAME}$  | grep ${FRONTEND_CONTAINER_NAME})
BS_STATS_STARTED := $(shell docker ps --no-trunc --filter name=^/${STATS_CONTAINER_NAME}$  | grep ${STATS_CONTAINER_NAME})
BS_STATS_DB_STARTED := $(shell docker ps --no-trunc --filter name=^/${STATS_DB_CONTAINER_NAME}$  | grep ${STATS_DB_CONTAINER_NAME})
BS_VISUALIZER_STARTED := $(shell docker ps --no-trunc --filter name=^/${VISUALIZER_CONTAINER_NAME}$  | grep ${VISUALIZER_CONTAINER_NAME})
BS_SIG_PROVIDER_STARTED := $(shell docker ps --no-trunc --filter name=^/${SIG_PROVIDER_CONTAINER_NAME}$  | grep ${SIG_PROVIDER_CONTAINER_NAME})
BS_PROXY_STARTED := $(shell docker ps --no-trunc --filter name=^/${PROXY_CONTAINER_NAME}$  | grep ${PROXY_CONTAINER_NAME})
stop:
ifdef BS_FRONTEND_STARTED
	@echo "==> Stopping Blockscout frontend container."
	@docker stop $(FRONTEND_CONTAINER_NAME) && docker rm -f $(FRONTEND_CONTAINER_NAME)
	@echo "==> Blockscout frontend container stopped."
else
	@echo "==> Blockscout frontend container already stopped before."
endif
ifdef BS_BACKEND_STARTED
	@echo "==> Stopping Blockscout backend container."
	@docker stop $(BACKEND_CONTAINER_NAME)  && docker rm -f $(BACKEND_CONTAINER_NAME)
	@echo "==> Blockscout backend container stopped."
else
	@echo "==> Blockscout backend container already stopped before."
endif
ifdef BS_STATS_DB_STARTED
	@echo "==> Stopping Blockscout stats db container."
	@docker stop $(STATS_DB_CONTAINER_NAME) && docker rm -f $(STATS_DB_CONTAINER_NAME)
	@echo "==> Blockscout stats db container stopped."
else
	@echo "==> Blockscout stats db container already stopped before."
endif
ifdef BS_STATS_STARTED
	@echo "==> Stopping Blockscout stats container."
	@docker stop $(STATS_CONTAINER_NAME) && docker rm -f $(STATS_CONTAINER_NAME)
	@echo "==> Blockscout stats container stopped."
else
	@echo "==> Blockscout stats container already stopped before."
endif
ifdef BS_VISUALIZER_STARTED
	@echo "==> Stopping Blockscout visualizer container."
	@docker stop $(VISUALIZER_CONTAINER_NAME) && docker rm -f $(VISUALIZER_CONTAINER_NAME)
	@echo "==> Blockscout visualizer container stopped."
else
	@echo "==> Blockscout visualizer container already stopped before."
endif
ifdef BS_SIG_PROVIDER_STARTED
	@echo "==> Stopping Blockscout sig-provider container."
	@docker stop $(SIG_PROVIDER_CONTAINER_NAME) && docker rm -f $(SIG_PROVIDER_CONTAINER_NAME)
	@echo "==> Blockscout sig-provider container stopped."
else
	@echo "==> Blockscout sig-provider container already stopped before."
endif
ifdef BS_PROXY_STARTED
	@echo "==> Stopping Nginx proxy container."
	@docker stop $(PROXY_CONTAINER_NAME) && docker rm -f $(PROXY_CONTAINER_NAME)
	@echo "==> Nginx proxy container stopped."
else
	@echo "==> Nginx proxy container already stopped before."
endif
ifdef PG_STARTED
	@echo "==> Stopping Postgres container."
	@docker stop $(PG_CONTAINER_NAME)
	@echo "==> Postgres container stopped."
else
	@echo "==> Postgres container already stopped before."
endif

run: start

.PHONY: build \
				start \
				stop \
				run
