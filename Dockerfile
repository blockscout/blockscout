FROM docker:dind

WORKDIR /app

RUN apk update
RUN apk add curl

# RUN set -ex && apk --no-cache add sudo

RUN curl -L "https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose
RUN ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

RUN apk add --no-cache make

COPY ./docker-compose ./docker-compose
COPY ./Makefile ./Makefile

# ENTRYPOINT ["dockerd"]

# RUN nohup sh -c 'dockerd && docker pull blockscout/blockscout:latest' > /dev/null &

# RUN dockerd