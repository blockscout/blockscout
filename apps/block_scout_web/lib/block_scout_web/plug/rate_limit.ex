defmodule BlockScoutWeb.Plug.RateLimit do
  @moduledoc """
    Rate limiting
  """
  alias BlockScoutWeb.{AccessHelper, RateLimit}
  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    config = fetch_rate_limit_config(conn)

    conn
    |> handle_call(config)
    |> case do
      {:deny, _time_to_reset, _limit, _period} = result ->
        conn
        |> set_rate_limit_headers(result)
        |> set_rate_limit_headers_for_frontend(config)
        |> AccessHelper.handle_rate_limit_deny(!api_v2?(conn))

      result ->
        conn
        |> set_rate_limit_headers(result)
        |> set_rate_limit_headers_for_frontend(config)
    end
  end

  defp set_rate_limit_headers(conn, result) do
    case result do
      {:allow, -1} ->
        conn
        |> Conn.put_resp_header("x-ratelimit-limit", "-1")
        |> Conn.put_resp_header("x-ratelimit-remaining", "-1")
        |> Conn.put_resp_header("x-ratelimit-reset", "-1")

      {:allow, count, limit, period} ->
        now = System.system_time(:millisecond)
        window = div(now, period)
        expires_at = (window + 1) * period

        conn
        |> Conn.put_resp_header("x-ratelimit-limit", "#{limit}")
        |> Conn.put_resp_header("x-ratelimit-remaining", "#{limit - count}")
        |> Conn.put_resp_header("x-ratelimit-reset", "#{expires_at - now}")

      {:deny, time_to_reset, limit, _time_interval} ->
        conn
        |> Conn.put_resp_header("x-ratelimit-limit", "#{limit}")
        |> Conn.put_resp_header("x-ratelimit-remaining", "0")
        |> Conn.put_resp_header("x-ratelimit-reset", "#{time_to_reset}")
    end
  end

  defp set_rate_limit_headers_for_frontend(conn, config) do
    user_agent = RateLimit.get_user_agent(conn)

    option =
      cond do
        config[:recaptcha_to_bypass_429] && user_agent -> "recaptcha"
        config[:temporary_token] && user_agent -> "temporary_token"
        !is_nil(config) -> "no_bypass"
        true -> "no_bypass"
      end

    conn
    |> Conn.put_resp_header("bypass-429-option", option)
  end

  defp handle_call(conn, config) do
    if graphql?(conn) do
      RateLimit.check_rate_limit_graphql(conn, 1)
    else
      RateLimit.rate_limit_with_config(conn, config)
    end
  end

  defp fetch_rate_limit_config(conn) do
    request_path = request_path(conn)
    config = :persistent_term.get(:rate_limit_config)

    if res = config[:static_match][request_path] do
      res
    else
      find_endpoint_config(config, conn.path_info) || config[:static_match]["default"]
    end
  end

  defp find_endpoint_config(config, request_path_parts) do
    config[:parametrized_match]
    |> Enum.find({nil, nil}, fn {key, _config} ->
      length(key) == length(request_path_parts) &&
        key |> Enum.zip(request_path_parts) |> Enum.all?(fn {k, r} -> k == r || k == ":param" end)
    end)
    |> elem(1) ||
      config[:wildcard_match]
      |> Enum.find({nil, nil}, fn {{key, length}, _config} when is_integer(length) ->
        Enum.take(request_path_parts, length) == key
      end)
      |> elem(1)
  end

  defp graphql?(conn) do
    request_path = request_path(conn)
    request_path == "api/v1/graphql" or request_path == "graphiql"
  end

  defp request_path(conn) do
    Enum.join(conn.path_info, "/")
  end

  defp api_v2?(conn) do
    conn.path_info |> Enum.take(2) == ["api", "v2"]
  end
end
