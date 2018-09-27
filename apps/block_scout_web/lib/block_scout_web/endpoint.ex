defmodule BlockScoutWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :block_scout_web

  if Application.get_env(:block_scout_web, :sql_sandbox) do
    plug(Phoenix.Ecto.SQL.Sandbox, repo: Explorer.Repo)
  end

  socket("/socket", BlockScoutWeb.UserSocket)
  socket("/wobserver", Wobserver.Web.PhoenixSocket)

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug(
    Plug.Static,
    at: "/",
    from: :block_scout_web,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
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
    store: :cookie,
    key: "_explorer_key",
    signing_salt: "iC2ksJHS"
  )

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
