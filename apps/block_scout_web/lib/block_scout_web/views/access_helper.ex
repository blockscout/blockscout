defmodule BlockScoutWeb.AccessHelper do
  @moduledoc """
  Helper to restrict access to some pages filtering by address
  """

  import Phoenix.Controller

  alias BlockScoutWeb.API.APILogger
  alias BlockScoutWeb.API.RPC.RPCView
  alias BlockScoutWeb.API.V2.ApiView
  alias BlockScoutWeb.Routers.WebRouter.Helpers
  alias Explorer.{AccessHelper, Chain}
  alias Plug.Conn

  alias RemoteIp

  require Logger

  @invalid_address_hash "Invalid address hash"
  @restricted_access "Restricted access"

  def restricted_access?(address_hash, params) do
    AccessHelper.restricted_access?(address_hash, params)
  end

  @doc """
  Checks if the given address hash string is valid and not restricted.

  ## Parameters
  - address_hash_string: A string representing the address hash to be validated.

  ## Returns
  - :ok if the address hash is valid and access is not restricted.
  - binary with reason otherwise.
  """
  @spec valid_address_hash_and_not_restricted_access?(binary()) :: :ok | binary()
  def valid_address_hash_and_not_restricted_access?(address_hash_string) do
    with address_hash when not is_nil(address_hash) <- Chain.string_to_address_hash_or_nil(address_hash_string),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, %{}) do
      :ok
    else
      nil ->
        @invalid_address_hash

      {:restricted_access, true} ->
        @restricted_access
    end
  end

  def get_path(conn, path, template, address_hash) do
    basic_args = [conn, template, address_hash]
    key = get_restricted_key(conn)
    # credo:disable-for-next-line
    full_args = if key, do: basic_args ++ [%{:key => key}], else: basic_args

    apply(Helpers, path, full_args)
  end

  def get_path(conn, path, template, address_hash, additional_params) do
    basic_args = [conn, template, address_hash]
    key = get_restricted_key(conn)
    full_additional_params = if key, do: Map.put(additional_params, :key, key), else: additional_params
    # credo:disable-for-next-line
    full_args = basic_args ++ [full_additional_params]

    apply(Helpers, path, full_args)
  end

  @doc """
  Handles a rate limit deny.

  ## Parameters
  - conn: The connection to handle.
  - api_v1?: Whether the API is v1.

  ## Returns
  - A connection with the status code 429 and the view set to ApiView if api_v2? is true, otherwise the view is set to RPCView.
  """
  @spec handle_rate_limit_deny(Plug.Conn.t(), boolean()) :: Plug.Conn.t()
  def handle_rate_limit_deny(conn, api_v1?) do
    APILogger.message("API rate limit reached")

    view = if api_v1?, do: RPCView, else: ApiView
    tag = if api_v1?, do: :error, else: :message

    conn
    |> Conn.put_status(429)
    |> put_view(view)
    |> render(tag, %{tag => "Too Many Requests"})
    |> Conn.halt()
  end

  defp get_restricted_key(%Phoenix.Socket{}), do: nil

  defp get_restricted_key(conn) do
    conn_with_params = Conn.fetch_query_params(conn)
    conn_with_params.query_params["key"]
  end

  @doc """
  Converts a connection to an IP string.

  ## Parameters
  - conn: The connection to convert.

  ## Returns
  - A string representing the IP address. If the connection is behind a proxy, the IP address from the headers is used.
  """
  @spec conn_to_ip_string(Plug.Conn.t()) :: String.t()
  def conn_to_ip_string(conn) do
    is_blockscout_behind_proxy = Application.get_env(:block_scout_web, :api_rate_limit)[:is_blockscout_behind_proxy]

    remote_ip_from_headers = is_blockscout_behind_proxy && RemoteIp.from(conn.req_headers)
    ip = remote_ip_from_headers || conn.remote_ip

    to_string(:inet_parse.ntoa(ip))
  end
end
