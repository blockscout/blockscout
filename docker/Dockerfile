FROM hexpm/elixir:1.14.5-erlang-25.3.2.4-alpine-3.18.2 AS builder

WORKDIR /app

RUN apk --no-cache --update add alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3 file gcompat

ENV PORT=4000 \
    MIX_ENV="prod"

RUN apk --update add libstdc++ curl ca-certificates gcompat

ARG CACHE_EXCHANGE_RATES_PERIOD
ARG API_V1_READ_METHODS_DISABLED
ARG DISABLE_WEBAPP
ARG API_V1_WRITE_METHODS_DISABLED
ARG CACHE_TOTAL_GAS_USAGE_COUNTER_ENABLED
ARG ADMIN_PANEL_ENABLED
ARG CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL
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

ENV MIX_HOME=/opt/mix
RUN mix local.hex --force
RUN HEX_HTTP_TIMEOUT=3600 mix do deps.get, local.rebar --force, deps.compile

ADD apps ./apps
ADD config ./config
ADD rel ./rel
ADD *.exs ./

# Run forderground build and phoenix digest
RUN mix compile

RUN apk update && \
    apk del --force-broken-world alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3

RUN apk add --update git make 

RUN export "CFLAGS=-I/usr/local/include -L/usr/local/lib" && cd deps/ex_secp256k1 && mix deps.get && mix compile
RUN mix phx.digest

RUN mkdir -p /opt/release \
  && mix release blockscout \
  && mv _build/${MIX_ENV}/rel/blockscout /opt/release

##############################################################
FROM hexpm/elixir:1.14.5-erlang-25.3.2.4-alpine-3.18.2

ARG RELEASE_VERSION
ENV RELEASE_VERSION=${RELEASE_VERSION}
ARG BLOCKSCOUT_VERSION
ENV BLOCKSCOUT_VERSION=${BLOCKSCOUT_VERSION}

RUN apk --no-cache --update add jq curl

WORKDIR /app

COPY --from=builder /opt/release/blockscout .
COPY --from=builder /app/config/config_helper.exs ./config/config_helper.exs
COPY --from=builder /app/config/config_helper.exs /app/releases/${RELEASE_VERSION}/config_helper.exs
