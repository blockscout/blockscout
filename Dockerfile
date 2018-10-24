FROM bitwalker/alpine-elixir-phoenix:latest

RUN apk --no-cache --update add automake libtool inotify-tools autoconf

EXPOSE 4000

ENV PORT=4000 \
    MIX_ENV="prod" \
    ETHEREUM_JSONRPC_VARIANT="ganache" \
    ETHEREUM_JSONRPC_HTTP_URL="http://host.docker.internal:7545" \
    ETHEREUM_JSONRPC_WEB_SOCKET_URL="ws://host.docker.internal:7545" \
    DATABASE_URL="postgresql://postgres:@host.docker.internal:5432/explorer?ssl=false" \
    SECRET_KEY_BASE="RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5"

# Cache elixir deps
ADD mix.exs mix.lock ./
ADD apps/block_scout_web/mix.exs ./apps/block_scout_web/
ADD apps/explorer/mix.exs ./apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs ./apps/indexer/

RUN mix do deps.get, deps.compile

ADD . .

# Run forderground build and phoenix digest
RUN mix compile

# Add blockscout npm deps
RUN cd apps/block_scout_web/assets/ && \
    npm install && \
    npm run deploy && \
    cd -

RUN cd apps/explorer/ && \
    npm install && \
    cd -

# RUN mix do ecto.drop --force, ecto.create, ecto.migrate

# USER default

# CMD ["mix", "phx.server"]
