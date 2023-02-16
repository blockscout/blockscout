#To stop the container, please user below command
docker-compose -f docker-compose/docker-compose-no-build-ganache.yml down --remove-orphans

#This command is used to build docker
docker build -f docker/Dockerfile . -t local/blockscout

#This command is used for to run the docker with compose file
docker-compose -f docker-compose/docker-compose-no-build-ganache.yml up -d 

#To view the logs then use below command
docker logs blockscout -f

