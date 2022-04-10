defmodule BlockScoutWeb.AccessHelpers do
  @moduledoc """
  Helpers to restrict access to some pages filtering by address
  """

  import Phoenix.Controller

  alias BlockScoutWeb.API.APILogger
  alias BlockScoutWeb.API.RPC.RPCView
  alias BlockScoutWeb.WebRouter.Helpers
  alias Explorer.Account.Api.Key, as: ApiKey
  alias Plug.Conn

  alias RemoteIp

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
      global_api_rate_limit = Application.get_env(:block_scout_web, :api_rate_limit)[:global_limit]
      api_rate_limit_by_key = Application.get_env(:block_scout_web, :api_rate_limit)[:api_rate_limit_by_key]
      api_rate_limit_by_ip = Application.get_env(:block_scout_web, :api_rate_limit)[:limit_by_ip]
      static_api_key = Application.get_env(:block_scout_web, :api_rate_limit)[:static_api_key]

      remote_ip = conn.remote_ip
      remote_ip_from_headers = RemoteIp.from(conn.resp_headers)
      ip = remote_ip_from_headers || remote_ip
      ip_string = to_string(:inet_parse.ntoa(ip))

      plan = get_plan(conn.query_params)

      cond do
        conn.query_params && Map.has_key?(conn.query_params, "apikey") &&
            Map.get(conn.query_params, "apikey") == static_api_key ->
          rate_limit_by_key(static_api_key, api_rate_limit_by_key)

        conn.query_params && Map.has_key?(conn.query_params, "apikey") && !is_nil(plan) ->
          conn.query_params
          |> Map.get("apikey")
          |> rate_limit_by_key(plan.max_req_per_second)

        Enum.member?(api_rate_limit_whitelisted_ips(), ip_string) ->
          rate_limit_by_ip(ip_string, api_rate_limit_by_ip)

        true ->
          global_rate_limit(global_api_rate_limit)
      end
    end
  end

  defp get_plan(query_params) do
    with true <- query_params && Map.has_key?(query_params, "apikey"),
         {:ok, casted_api_key} <- ApiKey.cast_api_key(Map.get(query_params, "apikey")),
         api_key <- ApiKey.api_key_with_plan_by_api_key(casted_api_key),
         true <- !is_nil(api_key) do
      api_key.identity.plan
    else
      _ ->
        nil
    end
  end

  defp rate_limit_by_key(api_key, api_rate_limit_by_key) do
    case Hammer.check_rate("api-#{api_key}", 1_000, api_rate_limit_by_key) do
      {:allow, _count} ->
        :ok

      {:deny, _limit} ->
        :rate_limit_reached
    end
  end

  defp rate_limit_by_ip(ip_string, api_rate_limit_by_ip) do
    case Hammer.check_rate("api-#{ip_string}", 1_000, api_rate_limit_by_ip) do
      {:allow, _count} ->
        :ok

      {:deny, _limit} ->
        :rate_limit_reached
    end
  end

  defp global_rate_limit(global_api_rate_limit) do
    case Hammer.check_rate("api", 1_000, global_api_rate_limit) do
      {:allow, _count} ->
        :ok

      {:deny, _limit} ->
        :rate_limit_reached
    end
  end

  defp get_restricted_key(%Phoenix.Socket{}) do
    nil
  end

  defp get_restricted_key(conn) do
    conn_with_params = Conn.fetch_query_params(conn)
    conn_with_params.query_params["key"]
  end

  defp api_rate_limit_whitelisted_ips do
    with api_rate_limit_object <-
           :block_scout_web
           |> Application.get_env(:api_rate_limit),
         {:ok, whitelisted_ips_string} <-
           api_rate_limit_object &&
             api_rate_limit_object
             |> Keyword.fetch(:whitelisted_ips) do
      if whitelisted_ips_string, do: String.split(whitelisted_ips_string, ","), else: []
    else
      _ -> []
    end
  end
end
