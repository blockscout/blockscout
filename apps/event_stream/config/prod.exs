import Config

config :event_stream, EventStream.Endpoint,
  url: [host: "example.com", port: 80],
  check_origin: ["//localhost"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  http: [
    # Enable IPv6 and bind on all interfaces.
    # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
    # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
    # for details about using IPv6 vs IPv4 and loopback vs public addresses.
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000")
  ],
  server: true,
  # this is not a secret this is for csrf + cookie encryption - we don't use any of these in this app
  secret_key_base: "RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5"
