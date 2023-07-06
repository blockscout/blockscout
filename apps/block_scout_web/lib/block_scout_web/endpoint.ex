defmodule BlockScoutWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :block_scout_web
  use Absinthe.Phoenix.Endpoint

  if Application.compile_env(:block_scout_web, :sql_sandbox) do
    plug(Phoenix.Ecto.SQL.Sandbox, repo: Explorer.Repo)
  end

  socket("/socket", BlockScoutWeb.UserSocket, websocket: [timeout: 45_000])
  socket("/socket/v2", BlockScoutWeb.UserSocketV2, websocket: [timeout: 45_000])

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug(
    Plug.Static,
    at: "/",
    from: :block_scout_web,
    gzip: true,
    only: ~w(
      css
      fonts
      images
      js
      android-chrome-192x192.png
      android-chrome-512x512.png
      apple-touch-icon.png
      browserconfig.xml
      mstile-150x150.png
      safari-pinned-tab.svg
      robots.txt
    ),
    only_matching: ~w(manifest)
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    length: 20_000_000,
    query_string_length: 1_000_000,
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.

  plug(
    Plug.Session,
    store: BlockScoutWeb.Plug.RedisCookie,
    key: "_explorer_key",
    signing_salt: "iC2ksJHS",
    same_site: "Lax",
    http_only: false,
    domain: Application.compile_env(:block_scout_web, :cookie_domain),
    max_age: Application.compile_env(:block_scout_web, :session_cookie_ttl)
  )

  use SpandexPhoenix

  plug(BlockScoutWeb.Prometheus.Exporter)

  # 'x-apollo-tracing' header for https://www.graphqlbin.com to work with our GraphQL endpoint
  plug(CORSPlug, headers: ["x-apollo-tracing" | CORSPlug.defaults()[:headers]])

  plug(BlockScoutWeb.Router)

  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end
end
