FROM bitwalker/alpine-elixir-phoenix:1.13

WORKDIR /app

RUN apk --no-cache --update add alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3 file qemu-x86_64 jq

# Get Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="$HOME/.cargo/bin:${PATH}"
ENV RUSTFLAGS="-C target-feature=-crt-static"

EXPOSE 4000

ARG SECRET_KEY_BASE
ENV PORT=4000 \
    MIX_ENV="prod" \
    SECRET_KEY_BASE="${SECRET_KEY_BASE}"

# Cache elixir deps
ADD mix.exs mix.lock ./
ADD apps/block_scout_web/mix.exs ./apps/block_scout_web/
ADD apps/explorer/mix.exs ./apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs ./apps/indexer/

RUN mix do deps.get, local.rebar --force, deps.compile

ADD . .

COPY . .

ARG COIN
# ARG GITHUB_TOKEN
RUN if [ "$COIN" != "" ]; then sed -i s/"ASA"/"${COIN}"/g apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po; fi

# Run forderground build and phoenix digest
RUN mix compile && npm install -g npm@latest
# RUN npm config set "@astraprotocol:registry" "https://npm.pkg.github.com"
# RUN npm config set "//npm.pkg.github.com/:_authToken" "${GITHUB_TOKEN}"

# Add blockscout npm deps
RUN cd apps/block_scout_web/assets/ && \
    npm install && \
    npm run deploy && \
    cd /app/apps/explorer/ && \
    npm install && \
    apk update && \
    apk del --force-broken-world alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3

RUN mix phx.digest