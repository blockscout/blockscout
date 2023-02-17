FROM bitwalker/alpine-elixir-phoenix:1.13 AS builder

WORKDIR /app

RUN apk --no-cache --update add alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3 file qemu-x86_64

ENV GLIBC_REPO=https://github.com/sgerrand/alpine-pkg-glibc \
    GLIBC_VERSION=2.30-r0 \
    PORT=4000 \
    MIX_ENV="prod" \
    PATH="$HOME/.cargo/bin:${PATH}" \
    RUSTFLAGS="-C target-feature=-crt-static"

RUN set -ex && \
    apk --update add libstdc++ curl ca-certificates && \
    for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION}; \
        do curl -sSL ${GLIBC_REPO}/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk; done && \
    apk add --allow-untrusted /tmp/*.apk && \
    rm -v /tmp/*.apk && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib

# Get Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ARG CACHE_EXCHANGE_RATES_PERIOD
ARG DISABLE_READ_API
ARG API_PATH
ARG NETWORK_PATH
ARG DISABLE_WEBAPP
ARG DISABLE_WRITE_API
ARG CACHE_ENABLE_TOTAL_GAS_USAGE_COUNTER
ARG WOBSERVER_ENABLED
ARG ADMIN_PANEL_ENABLED
ARG CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL
ARG SOCKET_ROOT
ARG SESSION_COOKIE_DOMAIN
ARG MIXPANEL_TOKEN
ARG MIXPANEL_URL
ARG AMPLITUDE_API_KEY
ARG AMPLITUDE_URL

# Cache elixir deps
ADD mix.exs mix.lock ./
ADD apps/block_scout_web/mix.exs ./apps/block_scout_web/
ADD apps/explorer/mix.exs ./apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs ./apps/indexer/

RUN HEX_HTTP_TIMEOUT=3600 mix do deps.get, local.rebar --force, deps.compile

ADD . .

COPY . .

# Run forderground build and phoenix digest
RUN mix compile && npm install npm@latest

# Add blockscout npm deps
RUN cd apps/block_scout_web/assets/ && \
    npm install && \
    npm run deploy && \
    cd /app/apps/explorer/ && \
    npm install && \
    apk update && \
    apk del --force-broken-world alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3

RUN mix phx.digest

RUN mkdir -p /opt/release \
  && mix release blockscout \
  && mv _build/${MIX_ENV}/rel/blockscout /opt/release

##############################################################
FROM bitwalker/alpine-elixir-phoenix:1.13

RUN apk --no-cache --update add jq

WORKDIR /app

COPY --from=builder /opt/release/blockscout .
COPY --from=builder /app/apps/explorer/node_modules ./node_modules
COPY --from=builder /app/config/config_helper.exs ./config/config_helper.exs
