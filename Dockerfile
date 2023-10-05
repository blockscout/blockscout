FROM ghcr.io/blockscout/frontend:latest as frontend
FROM blockscout/blockscout-suave:latest as backend

FROM node:18-alpine as blockscout

WORKDIR /app

RUN apk add libcrypto1.1
RUN apk add --no-cache --upgrade bash curl jq unzip

RUN set -ex && apk --no-cache add sudo

RUN apk add supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=backend /app ./backend
COPY --from=frontend /app ./frontend

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]