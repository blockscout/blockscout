# Extend from the official Elixir image.
FROM elixir:1.13.3

ENV MIX_ENV=prod

# Create app directory
#RUN git clone https://github.com/cloudwalk/blockscout.git
WORKDIR /blockscout
COPY . .

#
RUN apt-get update -y
RUN apt-get install rustc -y
RUN apt-get install npm -y && npm install npm@latest

# Install Hex package manager.
RUN mix local.hex --force
RUN mix local.rebar --force


RUN mix do deps.get
RUN mix deps.compile

RUN cd apps/block_scout_web/assets; npm install && node_modules/webpack/bin/webpack.js --mode production; cd -

RUN cd apps/explorer && npm install; cd -

RUN mix compile

ENTRYPOINT [ "mix", "phx.server" ]
