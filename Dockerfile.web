# TODO: Consider using distillery for smaller, self contained binaries
FROM bitwalker/alpine-elixir:1.7 as build
RUN apk add --update --no-cache alpine-sdk gmp-dev make automake autoconf libtool gcc git nodejs nodejs-npm python

WORKDIR /build

RUN git clone git://github.com/rebar/rebar.git

WORKDIR /build/rebar
RUN git checkout b6d3094
RUN ./bootstrap

WORKDIR /build

COPY config ./config
COPY mix.exs .
COPY mix.lock .
COPY apps ./apps
COPY mix.exs .

ENV MIX_ENV prod
RUN mix do deps.get, local.rebar --force, deps.compile, compile
RUN cd apps/block_scout_web/assets && npm install; npm run deploy; cd -
RUN cd apps/block_scout_web; mix phx.digest; cd -
RUN cd apps/explorer && npm install; cd -

WORKDIR /build/apps/block_scout_web
RUN echo $MIX_ENV

ENTRYPOINT ["mix"]
CMD ["phx.server"]