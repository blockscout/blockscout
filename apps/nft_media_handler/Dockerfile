# Multi-stage Dockerfile for building the nft_media_handler Elixir app
# - Builds the umbrella project (only what is needed)
# - Runs the nft_media_handler app in the final image using `mix run --no-halt`
# Notes:
# - This is a pragmatic Dockerfile that compiles the project and runs the app in prod mode.
# - For hardened production releases, consider using `mix release` and a smaller final image.

FROM elixir:1.19-slim AS builder
ARG MIX_ENV=prod
ENV MIX_ENV=${MIX_ENV}

# Install build dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only mix files first to fetch deps (speed up rebuilds)
COPY mix.exs mix.lock ./
COPY config ./config

# Copy the apps directory (we need the nft_media_handler app and shared code)
COPY apps ./apps

# Install Hex and Rebar, fetch and compile deps
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get --only ${MIX_ENV}
RUN mix deps.compile

# Compile project
RUN mix compile

# Final image
FROM elixir:1.19-slim AS app
ARG MIX_ENV=prod
ENV MIX_ENV=${MIX_ENV}

# Install runtime packages if needed
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled build from builder
COPY --from=builder /app/_build ./_build
COPY --from=builder /app/config ./config
COPY --from=builder /app/apps ./apps

# Set environment variables for Phoenix if needed
ENV PORT=4000
EXPOSE 4000

# Use a simple command to run the nft_media_handler app. In an umbrella
# this runs the whole release graph; if you have a release configured,
# replace this with the release start command.
CMD ["/bin/sh", "-c", "cd apps/nft_media_handler && MIX_ENV=prod mix run --no-halt"]
