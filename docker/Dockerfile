FROM bitwalker/alpine-elixir-phoenix:1.11.4

RUN apk --no-cache --update add alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3

# Get Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="$HOME/.cargo/bin:${PATH}"
ENV RUSTFLAGS="-C target-feature=-crt-static"

EXPOSE 4000

ENV MIX_ENV="prod"

# Cache elixir deps
ADD mix.exs mix.lock ./
ADD apps/block_scout_web/mix.exs ./apps/block_scout_web/
ADD apps/explorer/mix.exs ./apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs ./apps/indexer/

RUN HEX_HTTP_TIMEOUT=3600 mix do deps.get, local.rebar --force, deps.compile

ADD . .

ARG COIN
RUN if [ "$COIN" != "" ]; then sed -i s/"POA"/"${COIN}"/g apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po; fi

# Run forderground build and phoenix digest
RUN mix compile

RUN npm install npm@latest

# Add blockscout npm deps
RUN cd apps/block_scout_web/assets/ && \
    npm install && \
    npm run deploy && \
    cd -

RUN cd apps/explorer/ && \
    npm install && \
    apk update && apk del --force-broken-world alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3

RUN mix phx.digest
