.PHONY: start stop

start:
	docker-compose -f docker/docker-compose.yml up --build

stop:
	docker-compose -f docker/docker-compose.yml down