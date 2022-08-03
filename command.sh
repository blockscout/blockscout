docker-compose -f docker-compose/docker-compose-no-build-ganache.yml down --remove-orphans

docker build -f docker/Dockerfile . -t local/blockscout

docker-compose -f docker-compose/docker-compose-no-build-ganache.yml up -d 

docker logs blockscout -f

