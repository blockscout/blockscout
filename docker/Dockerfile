FROM bitwalker/alpine-elixir-phoenix:1.12

RUN apk --no-cache --update add alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3 file

ENV GLIBC_REPO=https://github.com/sgerrand/alpine-pkg-glibc
ENV GLIBC_VERSION=2.30-r0

RUN set -ex && \
    apk --update add libstdc++ curl ca-certificates && \
    for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION}; \
        do curl -sSL ${GLIBC_REPO}/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk; done && \
    apk add --allow-untrusted /tmp/*.apk && \
    rm -v /tmp/*.apk && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib

# Get Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ARG BUILD_ENV=dev

ENV PATH="$HOME/.cargo/bin:${PATH}"
ENV RUSTFLAGS="-C target-feature=-crt-static"

EXPOSE 4000

ENV PORT=4000 \
    SECRET_KEY_BASE="RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5"

# Cache elixir deps
ADD mix.exs mix.lock /src/
ADD apps/block_scout_web/mix.exs /src/apps/block_scout_web/
ADD apps/explorer/mix.exs /src/apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs /src/apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs /src/apps/indexer/

WORKDIR /src
RUN mix do deps.get, local.rebar --force, deps.compile

ADD . .

ARG COIN
RUN if [ "$COIN" != "" ]; then sed -i s/"POA"/"${COIN}"/g apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po; fi

# Run forderground build and phoenix digest
RUN mix compile

RUN npm install npm@latest

# Add blockscout npm deps
WORKDIR /src/apps/explorer
RUN npm install

WORKDIR /src/apps/block_scout_web/assets/
RUN npm install
RUN if [ "$BUILD_ENV" = "prod" ]; then  npm run deploy; fi

# Generate self signed cert for dev env
WORKDIR /src/apps/block_scout_web
RUN if [ "$BUILD_ENV" = "dev" ]; then mix phx.gen.cert blockscout blockscout.local; fi

WORKDIR /src
RUN if [ "$BUILD_ENV" = "prod" ]; then mix phx.digest; fi
CMD ["mix phx.server"]
