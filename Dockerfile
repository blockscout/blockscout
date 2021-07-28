# This dockerfile will combine all the stuff needed by blockscout
# into a single docker image for puppeth usage.
# Components include: local geth, postgres.

# Build go-ethereum
FROM ethereum/client-go:latest as builder

# Build postgres && blockscout
FROM bitwalker/alpine-elixir-phoenix:1.11.4 as phx-builder
# Get Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="$HOME/.cargo/bin:${PATH}"
ENV RUSTFLAGS="-C target-feature=-crt-static"

# Build blockscout
RUN apk --no-cache --update add alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3 file

ENV MIX_ENV="prod"

# Cache elixir deps
ADD mix.exs mix.lock ./
ADD apps/block_scout_web/mix.exs ./apps/block_scout_web/
ADD apps/explorer/mix.exs ./apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs ./apps/indexer/
RUN mix do deps.get, local.rebar --force, deps.compile

ADD . .

ARG COIN
RUN if [ "$COIN" != "" ]; then sed -i s/"POA"/"${COIN}"/g apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po; fi

ARG BLOCK_TRANSFORMER
RUN if [ "$BLOCK_TRANSFORMER" == "clique" ]; then sed -i s/"Validated"/"Signed"/g apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po; fi
RUN if [ "$BLOCK_TRANSFORMER" == "base" ]; then sed -i s/"Validated"/"Mined"/g apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po; fi
RUN if [ "$BLOCK_TRANSFORMER" == "clique" ]; then sed -i s/"Validator"/"Signer"/g apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po; fi
RUN if [ "$BLOCK_TRANSFORMER" == "base" ]; then sed -i s/"Validator"/"Miner"/g apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po; fi

# Add blockscout npm deps
RUN cd apps/explorer/ && \
    npm install

RUN cd apps/block_scout_web/assets/ && \
    npm install && \
    npm run deploy && \
    cd - && \
    mix do compile, phx.digest && \
    apk update && apk del --force-broken-world alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3


FROM postgres:13-alpine

COPY --from=phx-builder /opt/app/_build /opt/app/_build
COPY --from=phx-builder /opt/app/config /opt/app/config
COPY --from=phx-builder /opt/app/deps /opt/app/deps
COPY --from=phx-builder /opt/app/mix.* /opt/app/

ENV PORT=4000 \
    MIX_ENV="prod" \
    SECRET_KEY_BASE="RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5" \
    ETHEREUM_JSONRPC_VARIANT="geth" \
    ETHEREUM_JSONRPC_HTTP_URL="http://localhost:8545" \
    ETHEREUM_JSONRPC_WS_URL="ws://localhost:8546" \ 
    DATABASE_URL="postgresql://postgres:@localhost:5432/explorer?ssl=false" \
    POSTGRES_PASSWORD=\
    POSTGRES_USER=postgres\
    SUBNETWORK=\
    COIN="ETH"\
    POSTGRES_HOST_AUTH_METHOD="trust"\
    BLOCK_TRANSFORMER="base"

COPY --from=builder /usr/local/bin/geth /usr/local/bin

EXPOSE 4000

USER default
