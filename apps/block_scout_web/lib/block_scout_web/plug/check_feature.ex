defmodule BlockScoutWeb.Plug.CheckFeature do
  @moduledoc """
  A configurable plug that conditionally allows access to an endpoint based on
  whether a specific feature is enabled.

  ## Options

  * `:feature_check` - (Required) A function that returns a boolean indicating
    if the feature is enabled. Must be a 0-arity function or a captured function
    with all arguments supplied.

  * `:error_status` - (Optional) The HTTP status code to return when the feature
    is disabled. Defaults to 404.

  * `:error_message` - (Optional) The error message to return when the feature
    is disabled. Defaults to "Requested endpoint is disabled".

  ## Examples

  ```elixir
  # In a router
  pipeline :require_api_v2 do
    plug BlockScoutWeb.Plug.CheckFeature, feature_check: &ApiV2.enabled?/0
  end

  # In a controller
  plug BlockScoutWeb.Plug.CheckFeature,
    feature_check: &MyApp.Features.experimental_feature?/0,
    error_status: 403,
    error_message: "Experimental feature not available"
  ```

  When the feature is disabled, the connection will be halted and a JSON
  response with the configured status and message will be rendered.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2, render: 3]

  alias BlockScoutWeb.API.V2.ApiView

  @doc false
  @spec init(Keyword.t()) :: Keyword.t()
  def init(opts) do
    unless Keyword.has_key?(opts, :feature_check) do
      raise ArgumentError, "CheckFeature plug requires :feature_check option"
    end

    opts
    |> Keyword.put_new(:error_status, 404)
    |> Keyword.put_new(:error_message, "Requested endpoint is disabled")
  end

  @doc false
  @spec call(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def call(conn, opts) do
    enabled? = Keyword.fetch!(opts, :feature_check)
    status = Keyword.fetch!(opts, :error_status)
    message = Keyword.fetch!(opts, :error_message)

    if enabled?.() do
      conn
    else
      conn
      |> put_status(status)
      |> put_view(ApiView)
      |> render(:message, %{message: message})
      |> halt()
    end
  end
end
