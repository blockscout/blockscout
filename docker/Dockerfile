FROM hexpm/elixir:1.20.5-erlang-29.1.2-alpine-3.24.3 AS builder-deps

WORKDIR /app

RUN apk --no-cache --update add \
    alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3 file gcompat libstdc++ curl ca-certificates git make bash \
    ffmpeg-dev pkgconfig

# Cache elixir deps
COPY mix.exs mix.lock ./
COPY apps/block_scout_web/mix.exs ./apps/block_scout_web/
COPY apps/explorer/mix.exs ./apps/explorer/
COPY apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
COPY apps/indexer/mix.exs ./apps/indexer/
COPY apps/utils/mix.exs ./apps/utils/
COPY apps/nft_media_handler/mix.exs ./apps/nft_media_handler/

ENV MIX_ENV="prod"
ENV MIX_HOME=/opt/mix
RUN mix local.hex --force
RUN MIX_OS_DEPS_COMPILE_PARTITION_COUNT=$(nproc) mix do deps.get + local.rebar --force + deps.compile --skip-umbrella-children

COPY config ./config
COPY apps ./apps

##############################################################
FROM builder-deps AS builder

ENV DISABLE_WEBAPP=true
ENV ADMIN_PANEL_ENABLED=false
ARG DISABLE_API
ENV DISABLE_API=${DISABLE_API}
ARG API_V1_READ_METHODS_DISABLED
ENV API_V1_READ_METHODS_DISABLED=${API_V1_READ_METHODS_DISABLED}
ARG API_V1_WRITE_METHODS_DISABLED
ENV API_V1_WRITE_METHODS_DISABLED=${API_V1_WRITE_METHODS_DISABLED}
ARG CHAIN_TYPE
ENV CHAIN_TYPE=${CHAIN_TYPE}
ARG BRIDGED_TOKENS_ENABLED
ENV BRIDGED_TOKENS_ENABLED=${BRIDGED_TOKENS_ENABLED}
ARG API_GRAPHQL_MAX_COMPLEXITY
ENV API_GRAPHQL_MAX_COMPLEXITY=${API_GRAPHQL_MAX_COMPLEXITY}

# Run backend compilation
RUN mix compile

RUN mkdir -p /opt/release && \
    mix release blockscout && \
    mv _build/${MIX_ENV}/rel/blockscout /opt/release

##############################################################
FROM hexpm/elixir:1.20.5-erlang-29.1.2-alpine-3.24.3

# Unprivileged runtime account. Fixed numeric IDs keep ownership of mounted volumes stable.
ARG RUNTIME_USER=blockscout
ARG RUNTIME_GROUP=blockscout
ARG RUNTIME_UID=10001
ARG RUNTIME_GID=10001

RUN apk --no-cache --update add jq curl ffmpeg && \
    addgroup -S -g "${RUNTIME_GID}" "${RUNTIME_GROUP}" && \
    adduser -S -D -u "${RUNTIME_UID}" -G "${RUNTIME_GROUP}" -h /app "${RUNTIME_USER}"

WORKDIR /app

ENV DISABLE_WEBAPP=true
ENV ADMIN_PANEL_ENABLED=false
ARG DISABLE_API
ENV DISABLE_API=${DISABLE_API}
ARG API_V1_READ_METHODS_DISABLED
ENV API_V1_READ_METHODS_DISABLED=${API_V1_READ_METHODS_DISABLED}
ARG API_V1_WRITE_METHODS_DISABLED
ENV API_V1_WRITE_METHODS_DISABLED=${API_V1_WRITE_METHODS_DISABLED}
ARG CHAIN_TYPE
ENV CHAIN_TYPE=${CHAIN_TYPE}
ARG BRIDGED_TOKENS_ENABLED
ENV BRIDGED_TOKENS_ENABLED=${BRIDGED_TOKENS_ENABLED}
ARG API_GRAPHQL_MAX_COMPLEXITY
ENV API_GRAPHQL_MAX_COMPLEXITY=${API_GRAPHQL_MAX_COMPLEXITY}

ARG RELEASE_VERSION
ENV RELEASE_VERSION=${RELEASE_VERSION}
ARG BLOCKSCOUT_VERSION
ENV BLOCKSCOUT_VERSION=${BLOCKSCOUT_VERSION}

COPY --from=builder --chown=${RUNTIME_UID}:${RUNTIME_GID} /opt/release/blockscout ./
COPY --from=builder --chown=${RUNTIME_UID}:${RUNTIME_GID} /app/config/config_helper.exs ./config/
COPY --from=builder --chown=${RUNTIME_UID}:${RUNTIME_GID} /app/config/config_helper.exs ./releases/${RELEASE_VERSION}/
COPY --from=builder --chown=${RUNTIME_UID}:${RUNTIME_GID} /app/config/assets/precompiles-arbitrum.json ./config/assets/

RUN mkdir dets && mkdir temp && chown -R ${RUNTIME_UID}:${RUNTIME_GID} /app

USER ${RUNTIME_UID}:${RUNTIME_GID}
