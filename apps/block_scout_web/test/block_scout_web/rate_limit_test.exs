defmodule BlockScoutWeb.RateLimitTest do
  use BlockScoutWeb.ConnCase, async: false
  alias BlockScoutWeb.RateLimit

  describe "check_rate_limit_graphql/3" do
    setup do
      original_config = Application.get_env(:block_scout_web, Api.GraphQL)
      Application.put_env(:block_scout_web, Api.GraphQL, Keyword.put(original_config, :rate_limit_disabled?, false))

      on_exit(fn ->
        Application.put_env(:block_scout_web, Api.GraphQL, original_config)
        :ets.delete_all_objects(BlockScoutWeb.RateLimit.Hammer.ETS)
      end)
    end

    test "returns {:allow, -1} when rate limit is disabled" do
      Application.put_env(:block_scout_web, Api.GraphQL, rate_limit_disabled?: true)
      conn = build_conn()

      assert RateLimit.check_rate_limit_graphql(conn, 1) == {:allow, -1}
    end

    test "returns {:allow, -1} when using no_rate_limit_api_key" do
      no_rate_limit_api_key = "no_limit_key"
      Application.put_env(:block_scout_web, Api.GraphQL, no_rate_limit_api_key: no_rate_limit_api_key)
      conn = build_conn() |> Map.put(:query_params, %{"apikey" => no_rate_limit_api_key})

      assert RateLimit.check_rate_limit_graphql(conn, 1) == {:allow, -1}
    end

    test "applies rate limit for IP when no API key is provided" do
      Application.put_env(:block_scout_web, Api.GraphQL,
        rate_limit_disabled?: false,
        limit_by_ip: 100,
        time_interval_limit_by_ip: 60_000,
        time_interval_limit: 60_000,
        global_limit: 1000
      )

      conn = build_conn()

      assert {:allow, count, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
      assert count == 1
      assert limit == 100
      assert period == 60_000
    end

    test "global limit is applied when no API key is provided" do
      static_api_key = "static_key"

      Application.put_env(:block_scout_web, Api.GraphQL,
        rate_limit_disabled?: false,
        limit_by_ip: 100,
        time_interval_limit_by_ip: 50_000,
        time_interval_limit: 60_000,
        global_limit: 1,
        limit_by_key: 100,
        static_api_key: static_api_key
      )

      conn = build_conn()

      assert {:allow, count, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
      assert count == 1
      assert limit == 100
      assert period == 50_000

      assert {:deny, time_to_reset, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
      assert time_to_reset > 0 and time_to_reset < 60_000
      assert limit == 1
      assert period == 60_000

      conn = build_conn() |> Map.put(:query_params, %{"apikey" => static_api_key})

      assert {:allow, count, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
      assert count == 1
      assert limit == 100
      assert period == 60_000
    end

    test "bypass 429 rate limit with static API key" do
      static_api_key = "static_key"

      Application.put_env(:block_scout_web, Api.GraphQL,
        rate_limit_disabled?: false,
        limit_by_ip: 1,
        time_interval_limit_by_ip: 60_000,
        time_interval_limit: 1_000,
        global_limit: 1000,
        static_api_key: static_api_key,
        limit_by_key: 500
      )

      conn = build_conn()

      assert {:allow, count, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
      assert count == 1
      assert limit == 1
      assert period == 60_000

      assert {:deny, time_to_reset, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
      assert time_to_reset > 0 and time_to_reset < 60_000
      assert limit == 1
      assert period == 60_000

      conn = build_conn() |> Map.put(:query_params, %{"apikey" => static_api_key})

      assert {:allow, count, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
      assert count == 1
      assert limit == 500
      assert period == 1_000
    end

    test "applies rate limit for static API key" do
      static_api_key = "static_key"
      time_interval_limit = 500

      Application.put_env(:block_scout_web, Api.GraphQL,
        rate_limit_disabled?: false,
        static_api_key: static_api_key,
        time_interval_limit: time_interval_limit,
        limit_by_key: 500
      )

      conn = build_conn() |> Map.put(:query_params, %{"apikey" => static_api_key})

      # Make 500 requests to hit the limit
      Enum.each(1..500, fn i ->
        assert {:allow, count, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
        assert count == i
        assert limit == 500
        assert period == time_interval_limit
      end)

      # Next request should be denied
      assert {:deny, time_to_reset, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
      assert limit == 500
      assert period == time_interval_limit
      assert time_to_reset > 0 and time_to_reset < time_interval_limit

      Process.sleep(time_to_reset)

      # Make another request to check if it's allowed again
      assert {:allow, count, limit, period} = RateLimit.check_rate_limit_graphql(conn, 1)
      assert count == 1
      assert limit == 500
      assert period == time_interval_limit
    end
  end

  describe "rate_limit_with_config/2" do
    setup do
      original_config = Application.get_env(:block_scout_web, :api_rate_limit)
      Application.put_env(:block_scout_web, :api_rate_limit, Keyword.put(original_config, :disabled, false))
      original_recaptcha_config = Application.get_env(:block_scout_web, :recaptcha)

      on_exit(fn ->
        Application.put_env(:block_scout_web, :api_rate_limit, original_config)
        Application.put_env(:block_scout_web, :recaptcha, original_recaptcha_config)
        :ets.delete_all_objects(BlockScoutWeb.RateLimit.Hammer.ETS)
      end)
    end

    test "returns {:allow, -1} when rate limit is disabled globally" do
      Application.put_env(:block_scout_web, :api_rate_limit, disabled: true)
      conn = build_conn()

      assert RateLimit.rate_limit_with_config(conn, %{}) == {:allow, -1}
    end

    test "returns {:allow, -1} when endpoint is ignored" do
      conn = build_conn()

      assert RateLimit.rate_limit_with_config(conn, %{ignore: true}) == {:allow, -1}
    end

    test "applies rate limit by IP" do
      config = %{
        ip: %{
          period: 60_000,
          limit: 100
        }
      }

      conn = build_conn()

      assert {:allow, count, limit, period} = RateLimit.rate_limit_with_config(conn, config)
      assert count == 1
      assert limit == 100
      assert period == 60_000
    end

    test "applies rate limit by static API key" do
      static_api_key = "static_key"
      original_config = Application.get_env(:block_scout_web, :api_rate_limit)

      Application.put_env(
        :block_scout_web,
        :api_rate_limit,
        Keyword.put(original_config, :static_api_key_value, static_api_key)
      )

      config = %{
        temporary_token: %{
          period: 60_000,
          limit: 100
        },
        static_api_key: %{
          period: 60_000,
          limit: 500
        }
      }

      conn = build_conn() |> Map.put(:query_params, %{"apikey" => static_api_key})

      assert {:allow, count, limit, period} = RateLimit.rate_limit_with_config(conn, config)
      assert count >= 0
      assert limit == 500
      assert period == 60_000
    end

    test "applies rate limit by whitelisted IP" do
      ip = "192.168.1.1"
      original_config = Application.get_env(:block_scout_web, :api_rate_limit)
      Application.put_env(:block_scout_web, :api_rate_limit, Keyword.put(original_config, :whitelisted_ips, ip))

      config = %{
        temporary_token: %{
          period: 60_000,
          limit: 100
        },
        static_api_key: %{
          period: 60_000,
          limit: 200
        },
        account_api_key: %{
          period: 60_000,
          limit: 300
        },
        whitelisted_ip: %{
          period: 60_000,
          limit: 400
        },
        ip: %{
          period: 60_000,
          limit: 500
        }
      }

      conn = build_conn() |> Map.put(:remote_ip, {192, 168, 1, 1})

      assert {:allow, count, limit, period} = RateLimit.rate_limit_with_config(conn, config)
      assert count == 1
      assert limit == 400
      assert period == 60_000
    end

    test "applies rate limit by temporary token" do
      config = %{
        temporary_token: %{
          period: 60_000,
          limit: 100
        },
        static_api_key: %{
          period: 60_000,
          limit: 200
        },
        account_api_key: %{
          period: 60_000,
          limit: 300
        },
        whitelisted_ip: %{
          period: 60_000,
          limit: 400
        },
        ip: %{
          period: 60_000,
          limit: 1
        }
      }

      Application.put_env(
        :block_scout_web,
        :recaptcha,
        Keyword.put(Application.get_env(:block_scout_web, :recaptcha), :bypass_token, "test_token")
      )

      conn =
        build_conn()
        |> Map.put(:remote_ip, {192, 168, 1, 1})

      assert {:allow, count, limit, period} = RateLimit.rate_limit_with_config(conn, config)
      assert count == 1
      assert limit == 1
      assert period == 60_000

      assert {:deny, time_to_reset, limit, period} = RateLimit.rate_limit_with_config(conn, config)
      assert time_to_reset > 0 and time_to_reset < 60_000
      assert limit == 1
      assert period == 60_000

      # First make request to get temporary token
      conn =
        build_conn()
        |> Map.put(:remote_ip, {192, 168, 1, 1})
        |> Map.put(:req_headers, [{"user-agent", "test-agent"}])
        |> post("/api/v2/key", %{"recaptcha_bypass_token" => "test_token"})

      # Extract token from response
      token = conn.resp_cookies["api_v2_temp_token"].value

      # Now make request with the token
      conn =
        conn
        |> Map.put(:remote_ip, {192, 168, 1, 1})
        |> Map.put(:req_headers, [{"user-agent", "test-agent"}])
        |> Map.put(:req_cookies, %{"api_v2_temp_token" => token})

      assert {:allow, count, limit, period} = RateLimit.rate_limit_with_config(conn, config)
      assert count == 1
      assert limit == 100
      assert period == 60_000
    end

    test "handles recaptcha bypass" do
      config = %{
        temporary_token: %{
          period: 60_000,
          limit: 100
        },
        static_api_key: %{
          period: 60_000,
          limit: 200
        },
        account_api_key: %{
          period: 60_000,
          limit: 300
        },
        whitelisted_ip: %{
          period: 60_000,
          limit: 400
        },
        ip: %{
          period: 70_000,
          limit: 1
        },
        recaptcha_to_bypass_429: true
      }

      # First request to hit the limit
      conn = build_conn() |> Map.put(:req_headers, [{"user-agent", "test-agent"}])
      assert {:allow, 1, 1, _} = RateLimit.rate_limit_with_config(conn, config)

      # Second request that should be denied
      conn = build_conn() |> Map.put(:req_headers, [{"user-agent", "test-agent"}])
      assert {:deny, _, _, _} = RateLimit.rate_limit_with_config(conn, config)

      Application.put_env(
        :block_scout_web,
        :recaptcha,
        Keyword.put(Application.get_env(:block_scout_web, :recaptcha), :bypass_token, "test_token")
      )

      # Request with valid recaptcha
      conn =
        build_conn()
        |> Map.put(:req_headers, [
          {"user-agent", "test-agent"},
          {"recaptcha-bypass-token", "test_token"}
        ])

      assert {:allow, count, limit, period} = RateLimit.rate_limit_with_config(conn, config)
      assert count == 1
      assert limit == 1
      assert period == 70_000
    end
  end

  describe "get_user_agent/1" do
    test "returns user agent from headers" do
      conn = build_conn() |> Map.put(:req_headers, [{"user-agent", "test-agent"}])
      assert RateLimit.get_user_agent(conn) == "test-agent"
    end

    test "returns nil when user agent is not present" do
      conn = build_conn()
      assert RateLimit.get_user_agent(conn) == nil
    end
  end

  describe "rate_limit/4" do
    setup do
      original_config = Application.get_env(:block_scout_web, :api_rate_limit)
      Application.put_env(:block_scout_web, :api_rate_limit, Keyword.put(original_config, :disabled, false))

      on_exit(fn ->
        Application.put_env(:block_scout_web, :api_rate_limit, original_config)
        :ets.delete_all_objects(BlockScoutWeb.RateLimit.Hammer.ETS)
      end)
    end

    test "returns {:allow, count, limit, period} when under limit" do
      key = "test_key"
      period = 60_000
      limit = 100
      multiplier = 33

      assert {:allow, count, ^limit, ^period} = RateLimit.rate_limit(key, period, limit, multiplier)
      assert count == 33
    end

    test "returns {:deny, time_to_reset, limit, period} when over limit" do
      key = "test_key"
      period = 60_000
      limit = 1
      multiplier = 1

      # First request
      RateLimit.rate_limit(key, period, limit, multiplier)

      # Second request that should be denied
      assert {:deny, time_to_reset, ^limit, ^period} = RateLimit.rate_limit(key, period, limit, multiplier)
      assert time_to_reset > 0
    end
  end
end
