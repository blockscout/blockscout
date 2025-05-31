defmodule BlockScoutWeb.RateLimit do
  @moduledoc """
  Rate limiting
  """
  alias BlockScoutWeb.RateLimit.Hammer
  alias BlockScoutWeb.{AccessHelper, CaptchaHelper}
  alias Explorer.Account.Api.Key, as: ApiKey
  alias Plug.Conn

  require Logger

  @doc """
  Checks, if rate limit reached before making a new request. It is applied to GraphQL API.
  """
  @spec check_rate_limit_graphql(Plug.Conn.t(), integer()) ::
          {:allow, -1} | {:deny, integer(), integer(), integer()} | {:allow, integer(), integer(), integer()}
  def check_rate_limit_graphql(conn, multiplier) do
    config = Application.get_env(:block_scout_web, Api.GraphQL)
    no_rate_limit_api_key = config[:no_rate_limit_api_key]

    cond do
      config[:rate_limit_disabled?] ->
        {:allow, -1}

      check_no_rate_limit_api_key(conn, no_rate_limit_api_key) ->
        {:allow, -1}

      true ->
        check_graphql_rate_limit_inner(conn, config, multiplier)
    end
  end

  defp check_graphql_rate_limit_inner(conn, config, multiplier) do
    static_api_key = config[:static_api_key]

    ip_string = AccessHelper.conn_to_ip_string(conn)

    user_api_key = get_api_key(conn)

    with {:api_key, false} <- {:api_key, has_api_key_param?(conn) && user_api_key == static_api_key},
         {:plan, plan} when plan in [false, nil] <- {:plan, has_api_key_param?(conn) && get_plan(conn.query_params)} do
      ip_result =
        rate_limit("graphql_#{ip_string}", config[:time_interval_limit_by_ip], config[:limit_by_ip], multiplier)

      if match?({:allow, _}, ip_result) or match?({:allow, _, _, _}, ip_result) do
        maybe_replace_result(
          ip_result,
          rate_limit("graphql", config[:time_interval_limit], config[:global_limit], multiplier)
        )
      else
        ip_result
      end
    else
      {:api_key, true} ->
        rate_limit(static_api_key, config[:time_interval_limit], config[:limit_by_key], multiplier)

      {:plan, {plan, api_key}} ->
        rate_limit(
          api_key,
          config[:time_interval_limit],
          min(plan.max_req_per_second, config[:limit_by_key]),
          multiplier
        )
    end
  end

  defp maybe_replace_result(ip_result, {:allow, -1}) do
    ip_result
  end

  defp maybe_replace_result(ip_result, {:allow, _, _, _}) do
    ip_result
  end

  defp maybe_replace_result(_ip_result, global_result) do
    global_result
  end

  def rate_limit_with_config(conn, config) do
    config
    |> prepare_pipeline(conn)
    |> Enum.reject(&(is_nil(&1) || &1 == false))
    |> Enum.reduce_while(nil, fn fun, _acc ->
      case fun.(conn) do
        :skip -> {:cont, nil}
        result -> {:halt, result}
      end
    end)
    |> maybe_check_recaptcha_response(
      conn,
      get_user_agent(conn),
      config[:recaptcha_to_bypass_429],
      config[:bypass_token_scope]
    )
    |> case do
      nil ->
        Logger.error("Misconfiguration issue for #{conn.request_path}")
        {:allow, -1}

      result ->
        result
    end
  end

  defp prepare_pipeline(config, conn) do
    global_config = Application.get_env(:block_scout_web, :api_rate_limit)

    [
      global_config[:disabled] && fn _ -> {:allow, -1} end,
      config[:ignore] && fn _ -> {:allow, -1} end,
      check_no_rate_limit_api_key(conn, global_config[:no_rate_limit_api_key_value]) && fn _ -> {:allow, -1} end,
      config[:temporary_token] &&
        (&rate_limit_by_temporary_token(&1, config[:temporary_token], global_config[:temporary_token])),
      config[:static_api_key] &&
        (&rate_limit_by_static_api_key(&1, config[:static_api_key], global_config[:static_api_key], global_config)),
      config[:account_api_key] &&
        (&rate_limit_by_account_api_key(&1, config[:account_api_key], global_config[:account_api_key])),
      config[:whitelisted_ip] &&
        (&rate_limit_by_whitelisted_ip(&1, config[:whitelisted_ip], global_config[:whitelisted_ip], global_config)),
      config[:ip] &&
        (&rate_limit_by_ip(&1, config[:ip], global_config[:ip]))
    ]
  end

  defp maybe_check_recaptcha_response(result, conn, user_agent, true, scope) when not is_nil(user_agent) do
    case result do
      {:deny, _time_to_reset, limit, time_interval} ->
        conn
        |> check_recaptcha(scope)
        |> case do
          true ->
            {:allow, limit, limit, time_interval}

          false ->
            result
        end

      _ ->
        result
    end
  end

  defp maybe_check_recaptcha_response(result, _, _, _, _) do
    result
  end

  defp check_recaptcha(conn, scope) when is_binary(scope) do
    conn
    |> collect_recaptcha_headers()
    |> CaptchaHelper.recaptcha_passed?(String.to_atom(scope))
  end

  defp check_recaptcha(conn, _) do
    conn
    |> collect_recaptcha_headers()
    |> CaptchaHelper.recaptcha_passed?()
  end

  defp collect_recaptcha_headers(conn) do
    recaptcha_response = get_header_or_nil(conn, "recaptcha-v2-response")
    recaptcha_v3_response = get_header_or_nil(conn, "recaptcha-v3-response")
    recaptcha_bypass_token = get_header_or_nil(conn, "recaptcha-bypass-token")
    scoped_recaptcha_bypass_token = get_header_or_nil(conn, "scoped-recaptcha-bypass-token")

    cond do
      recaptcha_response ->
        %{
          "recaptcha_response" => recaptcha_response
        }

      recaptcha_v3_response ->
        %{
          "recaptcha_v3_response" => recaptcha_v3_response
        }

      scoped_recaptcha_bypass_token ->
        %{
          "scoped_recaptcha_bypass_token" => scoped_recaptcha_bypass_token
        }

      recaptcha_bypass_token ->
        %{
          "recaptcha_bypass_token" => recaptcha_bypass_token
        }

      true ->
        %{}
    end
  end

  defp get_header_or_nil(conn, header_name) do
    case Conn.get_req_header(conn, header_name) do
      [response] ->
        response

      _ ->
        nil
    end
  end

  defp rate_limit_by_static_api_key(conn, route_config, default_config, global_config) do
    config = config_or_default(route_config, default_config)
    static_api_key = global_config[:static_api_key_value]

    if has_api_key_param?(conn) && get_api_key(conn) == static_api_key do
      rate_limit(static_api_key, config[:period], config[:limit], config[:cost] || 1)
    else
      :skip
    end
  end

  @spec rate_limit_by_account_api_key(any(), any(), any()) ::
          :skip | {:allow, -1} | {:deny, integer(), integer(), integer()} | {:allow, integer(), integer(), integer()}
  defp rate_limit_by_account_api_key(conn, route_config, global_config) do
    config = config_or_default(route_config, global_config)
    plan = get_plan(conn.query_params)

    if plan do
      {plan, api_key} = plan
      rate_limit(api_key, config[:period], config[:limit] || plan.max_req_per_second, config[:cost] || 1)
    else
      :skip
    end
  end

  defp rate_limit_by_whitelisted_ip(conn, route_config, default_config, global_config) do
    config = config_or_default(route_config, default_config)
    ip_string = AccessHelper.conn_to_ip_string(conn)

    if Enum.member?(whitelisted_ips(global_config), ip_string) do
      rate_limit(ip_string, config[:period], config[:limit], config[:cost] || 1)
    else
      :skip
    end
  end

  defp rate_limit_by_temporary_token(conn, route_config, default_config) do
    config = config_or_default(route_config, default_config)
    ip_string = AccessHelper.conn_to_ip_string(conn)
    token = get_ui_v2_token(conn, ip_string)

    if token && !is_nil(get_user_agent(conn)) do
      rate_limit(token, config[:period], config[:limit], config[:cost] || 1)
    else
      :skip
    end
  end

  defp rate_limit_by_ip(conn, route_config, default_config) do
    config = config_or_default(route_config, default_config)
    ip_string = AccessHelper.conn_to_ip_string(conn)

    rate_limit(ip_string, config[:period], config[:limit], config[:cost] || 1)
  end

  @spec config_or_default(any(), any()) :: any()
  defp config_or_default(config, default) do
    if is_map(config) do
      config
    else
      default
    end
  end

  @spec rate_limit(String.t(), integer(), integer(), integer()) ::
          {:allow, integer(), integer(), integer()} | {:deny, integer(), integer(), integer()} | {:allow, -1}
  def rate_limit(key, time_interval, limit, multiplier) do
    case Hammer.hit(add_chain_prefix(key), time_interval, limit, multiplier) do
      {:allow, count} ->
        {:allow, count, limit, time_interval}

      {:deny, time_to_reset} ->
        {:deny, time_to_reset, limit, time_interval}

      {:error, error} ->
        Logger.error(fn -> ["Rate limit check error: ", inspect(error)] end)
        {:allow, -1}
    end
  end

  @spec add_chain_prefix(String.t()) :: String.t()
  defp add_chain_prefix(key) do
    chain_id = Application.get_env(:block_scout_web, :chain_id)
    "#{chain_id}_#{key}"
  end

  defp check_no_rate_limit_api_key(conn, no_rate_limit_api_key) do
    user_api_key = get_api_key(conn)

    has_api_key_param?(conn) && !is_nil(user_api_key) && String.trim(user_api_key) !== "" &&
      user_api_key == no_rate_limit_api_key
  end

  @doc """
  Get the user agent from the request headers.
  """
  @spec get_user_agent(Plug.Conn.t()) :: nil | binary()
  def get_user_agent(conn) do
    case Conn.get_req_header(conn, "user-agent") do
      [agent] ->
        agent

      _ ->
        nil
    end
  end

  defp get_ui_v2_token(conn, ip_string) do
    api_v2_temp_token_key = Application.get_env(:block_scout_web, :api_v2_temp_token_key)
    conn = Conn.fetch_cookies(conn, signed: [api_v2_temp_token_key])

    case conn.cookies[api_v2_temp_token_key] do
      %{ip: ^ip_string} ->
        conn.req_cookies[api_v2_temp_token_key]

      _ ->
        nil
    end
  end

  defp whitelisted_ips(api_rate_limit_object) do
    case api_rate_limit_object && api_rate_limit_object |> Keyword.fetch(:whitelisted_ips) do
      {:ok, whitelisted_ips_string} ->
        if whitelisted_ips_string, do: String.split(whitelisted_ips_string, ","), else: []

      _ ->
        []
    end
  end

  defp has_api_key_param?(conn), do: Map.has_key?(conn.query_params, "apikey")

  defp get_api_key(conn), do: Map.get(conn.query_params, "apikey")

  defp get_plan(query_params) do
    with true <- query_params && Map.has_key?(query_params, "apikey"),
         api_key_value <- Map.get(query_params, "apikey"),
         api_key when not is_nil(api_key) <- ApiKey.api_key_with_plan_by_value(api_key_value) do
      {api_key.identity.plan, to_string(api_key.value)}
    else
      _ ->
        nil
    end
  end
end
