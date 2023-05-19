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
  alias Plug.{Conn, Crypto}

  alias RemoteIp

  require Logger

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
    rate_limit_config = Application.get_env(:block_scout_web, :api_rate_limit)

    if rate_limit_config[:disabled] do
      :ok
    else
      check_rate_limit_inner(conn, rate_limit_config)
    end
  end

  # credo:disable-for-next-line /Complexity/
  defp check_rate_limit_inner(conn, rate_limit_config) do
    global_limit = rate_limit_config[:global_limit]
    limit_by_key = rate_limit_config[:limit_by_key]
    limit_by_whitelisted_ip = rate_limit_config[:limit_by_whitelisted_ip]
    time_interval_limit = rate_limit_config[:time_interval_limit]
    static_api_key = rate_limit_config[:static_api_key]
    limit_by_ip = rate_limit_config[:limit_by_ip]
    api_v2_ui_limit = rate_limit_config[:api_v2_ui_limit]
    time_interval_by_ip = rate_limit_config[:time_interval_limit_by_ip]

    ip_string = conn_to_ip_string(conn)

    plan = get_plan(conn.query_params)
    token = get_ui_v2_token(conn, conn.query_params, ip_string)

    user_agent = get_user_agent(conn)

    cond do
      check_api_key(conn) && get_api_key(conn) == static_api_key ->
        rate_limit(static_api_key, limit_by_key, time_interval_limit)

      check_api_key(conn) && !is_nil(plan) ->
        conn
        |> get_api_key()
        |> rate_limit(plan.max_req_per_second, time_interval_limit)

      Enum.member?(whitelisted_ips(rate_limit_config), ip_string) ->
        rate_limit(ip_string, limit_by_whitelisted_ip, time_interval_limit)

      is_api_v2_request?(conn) && !is_nil(token) && !is_nil(user_agent) ->
        rate_limit(token, api_v2_ui_limit, time_interval_limit)

      is_api_v2_request?(conn) && !is_nil(user_agent) ->
        rate_limit(ip_string, limit_by_ip, time_interval_by_ip)

      true ->
        rate_limit("api", global_limit, time_interval_limit)
    end
  end

  defp check_api_key(conn), do: Map.has_key?(conn.query_params, "apikey")

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

  defp rate_limit(key, limit, time_interval) do
    rate_limit_inner(key, time_interval, limit)
  end

  defp rate_limit_inner(key, time_interval, limit) do
    case Hammer.check_rate(key, time_interval, limit) do
      {:allow, _count} ->
        :ok

      {:deny, _limit} ->
        :rate_limit_reached

      {:error, error} ->
        Logger.error(fn -> ["Rate limit check error: ", inspect(error)] end)
        :ok
    end
  end

  defp get_restricted_key(%Phoenix.Socket{}), do: nil

  defp get_restricted_key(conn) do
    conn_with_params = Conn.fetch_query_params(conn)
    conn_with_params.query_params["key"]
  end

  defp whitelisted_ips(api_rate_limit_object) do
    case api_rate_limit_object && api_rate_limit_object |> Keyword.fetch(:whitelisted_ips) do
      {:ok, whitelisted_ips_string} ->
        if whitelisted_ips_string, do: String.split(whitelisted_ips_string, ","), else: []

      _ ->
        []
    end
  end

  defp is_api_v2_request?(%Plug.Conn{request_path: "/api/v2/" <> _}), do: true
  defp is_api_v2_request?(_), do: false

  def conn_to_ip_string(conn) do
    is_blockscout_behind_proxy = Application.get_env(:block_scout_web, :api_rate_limit)[:is_blockscout_behind_proxy]

    remote_ip_from_headers = is_blockscout_behind_proxy && RemoteIp.from(conn.req_headers)
    ip = remote_ip_from_headers || conn.remote_ip

    to_string(:inet_parse.ntoa(ip))
  end

  defp get_ui_v2_token(conn, %{"token" => token}, ip_string) do
    case is_api_v2_request?(conn) && Crypto.verify(conn.secret_key_base, conn.secret_key_base, token) do
      {:ok, %{ip: ^ip_string}} ->
        token

      _ ->
        nil
    end
  end

  defp get_ui_v2_token(_conn, _params, _ip_string), do: nil

  defp get_user_agent(conn) do
    case Conn.get_req_header(conn, "user-agent") do
      [agent] ->
        agent

      _ ->
        nil
    end
  end
end
