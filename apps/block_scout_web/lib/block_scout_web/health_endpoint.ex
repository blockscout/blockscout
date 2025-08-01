defmodule BlockScoutWeb.HealthEndpoint do
  @moduledoc """
  Health endpoint for health checks in case of indexer-only/standalone_media_worker setup
  """
  use Phoenix.Endpoint, otp_app: :block_scout_web

  plug(BlockScoutWeb.HealthRouter)

  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end
end
