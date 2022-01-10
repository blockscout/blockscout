defmodule BlockScoutWeb.AccessHelpers do
  @moduledoc """
  Helpers to restrict access to some pages filtering by address
  """

  import Phoenix.Controller

  alias BlockScoutWeb.API.APILogger
  alias BlockScoutWeb.API.RPC.RPCView
  alias BlockScoutWeb.WebRouter.Helpers
  alias Plug.Conn

  defp get_restricted_key(%Phoenix.Socket{}) do
    nil
  end

  defp get_restricted_key(conn) do
    conn_with_params = Conn.fetch_query_params(conn)
    conn_with_params.query_params["key"]
  end

  def restricted_access?(address_hash, params) do
    restricted_list_var = Application.get_env(:block_scout_web, :restricted_list)
    restricted_list = (restricted_list_var && String.split(restricted_list_var, ",")) || []

    if Enum.count(restricted_list) > 0 do
      formatted_restricted_list =
        restricted_list
        |> Enum.map(fn addr ->
          String.downcase(addr)
        end)

      formatted_address_hash = String.downcase(address_hash)

      address_restricted =
        formatted_restricted_list
        |> Enum.member?(formatted_address_hash)

      key = if params && Map.has_key?(params, "key"), do: Map.get(params, "key"), else: nil
      correct_key = key && key == Application.get_env(:block_scout_web, :restricted_list_key)

      if address_restricted && !correct_key, do: {:restricted_access, true}, else: {:ok, false}
    else
      {:ok, false}
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

  def handle_rate_limit_deny(conn) do
    APILogger.message("API rate limit reached")

    conn
    |> Conn.put_status(429)
    |> put_view(RPCView)
    |> render(:error, %{error: "429 Too Many Requests"})
    |> Conn.halt()
  end

  def check_rate_limit(conn) do
    if Mix.env() == :test do
      :ok
    else
      global_api_rate_limit = Application.get_env(:block_scout_web, :global_api_rate_limit)
      api_rate_limit_by_key = Application.get_env(:block_scout_web, :api_rate_limit_by_key)
      static_api_key = Application.get_env(:block_scout_web, :static_api_key)

      if conn.query_params && Map.has_key?(conn.query_params, "apikey") &&
           Map.get(conn.query_params, "apikey") == static_api_key do
        case Hammer.check_rate("api-#{static_api_key}", 1_000, api_rate_limit_by_key) do
          {:allow, _count} ->
            :ok

          {:deny, _limit} ->
            :rate_limit_reached
        end
      else
        case Hammer.check_rate("api", 1_000, global_api_rate_limit) do
          {:allow, _count} ->
            :ok

          {:deny, _limit} ->
            :rate_limit_reached
        end
      end
    end
  end
end
