.PHONY: start stop

start:
	docker-compose up --build

stop:
	docker-compose down