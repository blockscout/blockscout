DOCKER_REPO := blockscout
BACKEND_APP_NAME := blockscout
FRONTEND_APP_NAME := frontend
BACKEND_CONTAINER_IMAGE := $(DOCKER_REPO)/$(BACKEND_APP_NAME)
BACKEND_CONTAINER_NAME := backend
FRONTEND_CONTAINER_NAME := frontend
VISUALIZER_CONTAINER_NAME := visualizer
SIG_PROVIDER_CONTAINER_NAME := sig-provider
STATS_CONTAINER_NAME := stats
STATS_DB_CONTAINER_NAME := stats-db
PROXY_CONTAINER_NAME := proxy
PG_CONTAINER_NAME := postgres
RELEASE_VERSION ?= '9.3.5'
TAG := $(RELEASE_VERSION)-commit-$(shell git log -1 --pretty=format:"%h")
STABLE_TAG := $(RELEASE_VERSION)

start:
	@echo "==> Starting blockscout db"
	@docker-compose -f ../docker-compose/services/db.yml up -d
	@echo "==> Starting blockscout backend"
	@docker-compose -f ../docker-compose/services/backend.yml up -d
	@echo "==> Starting stats microservice"
	@docker-compose -f ../docker-compose/services/stats.yml up -d
	@echo "==> Starting visualizer microservice"
	@docker-compose -f ../docker-compose/services/visualizer.yml up -d
	@echo "==> Starting sig-provider microservice"
	@docker-compose -f ../docker-compose/services/sig-provider.yml up -d
	@echo "==> Starting blockscout frontend"
	@docker-compose -f ../docker-compose/services/frontend.yml up -d
	@echo "==> Starting Nginx proxy"
	@docker-compose -f ../docker-compose/services/nginx.yml up -d

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

docker-login: ## login to DockerHub with credentials found in env
	docker login -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD}

# Docker release - build, tag and push the container
pre-release: build publish ## Make a release by building and publishing the `{version}` ans `latest` tagged containers to hub
release: build publish-stable ## Make a release by building and publishing the `{version}` ans `latest` tagged containers to hub

# Docker publish
publish: docker-login publish-latest publish-version ## publish the `{version}` ans `latest` tagged containers to hub
publish-stable: docker-login publish-latest publish-stable-version ## publish the `{version}` ans `latest` tagged containers to hub

publish-latest: tag-latest ## publish the `latest` tagged container to hub
	@echo 'publish latest to $(DOCKER_REPO)'
	docker push $(BACKEND_CONTAINER_IMAGE):latest

publish-version: tag-version ## publish the `{version}` tagged container to hub
	@echo 'publish $(TAG) to $(DOCKER_REPO)'
	docker push $(BACKEND_CONTAINER_IMAGE):$(TAG)

publish-stable-version: tag-stable-version ## publish the `{version}` tagged container to hub
	@echo 'publish $(STABLE_TAG) to $(DOCKER_REPO)'
	docker push $(BACKEND_CONTAINER_IMAGE):$(STABLE_TAG)

# Docker tagging
tag: tag-latest tag-version ## Generate container tags for the `{version}` ans `latest` tags
tag-stable: tag-latest tag-stable-version ## Generate container tags for the `{version}` ans `latest` tags

tag-latest: ## Generate container `latest` tag
	@echo 'create latest tag'
	docker tag $(BACKEND_CONTAINER_IMAGE) $(BACKEND_CONTAINER_IMAGE):latest

tag-version: ## Generate container `{version}` tag
	@echo 'create tag $(TAG)'
	docker tag $(BACKEND_CONTAINER_IMAGE) $(BACKEND_CONTAINER_IMAGE):$(TAG)

tag-stable-version: ## Generate container `{version}` tag
	@echo 'create tag $(STABLE_TAG)'
	docker tag $(BACKEND_CONTAINER_IMAGE) $(BACKEND_CONTAINER_IMAGE):$(STABLE_TAG)

.PHONY: build \
				start \
				stop \
				run \
				docker-login \
				release \
				publish \
				publish-latest \
				publish-version \
				tag \
				tag-latest \
				tag-version
