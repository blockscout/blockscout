defmodule BlockScoutWeb.AccessHelper do
  @moduledoc """
  Helper to restrict access to some pages filtering by address
  """

  import Phoenix.Controller

  alias BlockScoutWeb.API.APILogger
  alias BlockScoutWeb.API.RPC.RPCView
  alias BlockScoutWeb.API.V2.ApiView
  alias BlockScoutWeb.WebRouter.Helpers
  alias Explorer.AccessHelper
  alias Explorer.Account.Api.Key, as: ApiKey
  alias Plug.Conn

  alias RemoteIp

  def restricted_access?(address_hash, params) do
    AccessHelper.restricted_access?(address_hash, params)
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

  def handle_rate_limit_deny(conn, api_v2? \\ false) do
    APILogger.message("API rate limit reached")

    view = if api_v2?, do: ApiView, else: RPCView
    tag = if api_v2?, do: :message, else: :error

    conn
    |> Conn.put_status(429)
    |> put_view(view)
    |> render(tag, %{tag => "429 Too Many Requests"})
    |> Conn.halt()
  end

  def check_rate_limit(conn) do
    if Application.get_env(:block_scout_web, :api_rate_limit)[:disabled] == true do
      :ok
    else
      is_blockscout_behind_proxy = Application.get_env(:block_scout_web, :api_rate_limit)[:is_blockscout_behind_proxy]

      global_api_rate_limit = Application.get_env(:block_scout_web, :api_rate_limit)[:global_limit]
      api_rate_limit_by_key = Application.get_env(:block_scout_web, :api_rate_limit)[:api_rate_limit_by_key]
      api_rate_limit_by_ip = Application.get_env(:block_scout_web, :api_rate_limit)[:limit_by_ip]
      static_api_key = Application.get_env(:block_scout_web, :api_rate_limit)[:static_api_key]

      remote_ip = conn.remote_ip
      remote_ip_from_headers = is_blockscout_behind_proxy && RemoteIp.from(conn.req_headers)
      ip = remote_ip_from_headers || remote_ip
      ip_string = to_string(:inet_parse.ntoa(ip))

      plan = get_plan(conn.query_params)

      cond do
        check_api_key(conn) && get_api_key(conn) == static_api_key ->
          rate_limit_by_param(static_api_key, api_rate_limit_by_key)

        check_api_key(conn) && !is_nil(plan) ->
          conn
          |> get_api_key()
          |> rate_limit_by_param(plan.max_req_per_second)

        Enum.member?(api_rate_limit_whitelisted_ips(), ip_string) ->
          rate_limit(ip_string, api_rate_limit_by_ip)

        true ->
          global_rate_limit(global_api_rate_limit)
      end
    end
  end

  defp check_api_key(conn), do: conn.query_params && Map.has_key?(conn.query_params, "apikey")

  defp get_api_key(conn), do: Map.get(conn.query_params, "apikey")

  defp get_plan(query_params) do
    with true <- query_params && Map.has_key?(query_params, "apikey"),
         api_key_value <- Map.get(query_params, "apikey"),
         api_key <- ApiKey.api_key_with_plan_by_value(api_key_value),
         false <- is_nil(api_key) do
      api_key.identity.plan
    else
      _ ->
        nil
    end
  end

  defp rate_limit_by_param(key, value) do
    rate_limit("api-#{key}", value)
  end

  defp global_rate_limit(global_api_rate_limit) do
    rate_limit("api", global_api_rate_limit)
  end

  defp rate_limit(key, value) do
    case Hammer.check_rate(key, 1_000, value) do
      {:allow, _count} ->
        :ok

      {:deny, _limit} ->
        :rate_limit_reached
    end
  end

  defp get_restricted_key(%Phoenix.Socket{}), do: nil

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
