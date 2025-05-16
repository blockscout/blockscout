defmodule BlockScoutWeb.Plug.RateLimitTest do
  use BlockScoutWeb.ConnCase, async: false

  setup do
    # Store original config
    original_config = :persistent_term.get(:rate_limit_config)

    original_recaptcha_config = Application.get_env(:block_scout_web, :recaptcha)
    original_rate_limit_config = Application.get_env(:block_scout_web, :api_rate_limit)
    original_graphql_config = Application.get_env(:block_scout_web, Api.GraphQL)

    Application.put_env(:block_scout_web, :api_rate_limit, Keyword.put(original_rate_limit_config, :disabled, false))

    Application.put_env(
      :block_scout_web,
      Api.GraphQL,
      Keyword.put(original_graphql_config, :rate_limit_disabled?, false)
    )

    on_exit(fn ->
      :persistent_term.put(:rate_limit_config, original_config)

      Application.put_env(:block_scout_web, :recaptcha, original_recaptcha_config)
      Application.put_env(:block_scout_web, :api_rate_limit, original_rate_limit_config)
      Application.put_env(:block_scout_web, Api.GraphQL, original_graphql_config)

      :ets.delete_all_objects(BlockScoutWeb.RateLimit.Hammer.ETS)
    end)
  end

  describe "rate limiting" do
    test "sets rate limit headers for allowed and denied requests", %{conn: conn} do
      config = %{
        static_match: %{
          "api/v2/blocks" => %{
            ip: %{
              period: 60_000,
              limit: 1
            }
          }
        },
        wildcard_match: %{},
        parametrized_match: %{}
      }

      :persistent_term.put(:rate_limit_config, config)

      # First request - allowed
      first_request = conn |> get("/api/v2/blocks")
      assert first_request.status == 200
      assert get_resp_header(first_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(first_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(first_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0
      assert get_resp_header(first_request, "bypass-429-option") == ["no_bypass"]

      # Second request - should be denied with 429
      second_request = conn |> get("/api/v2/blocks")
      assert second_request.status == 429
      assert get_resp_header(second_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(second_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(second_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0
      assert get_resp_header(second_request, "bypass-429-option") == ["no_bypass"]
    end

    test "handles recaptcha bypass option", %{conn: conn} do
      config = %{
        static_match: %{
          "api/v2/addresses" => %{
            ip: %{
              period: 60_000,
              limit: 1
            },
            recaptcha_to_bypass_429: true
          }
        },
        wildcard_match: %{},
        parametrized_match: %{}
      }

      :persistent_term.put(:rate_limit_config, config)

      # First request with user agent
      first_request =
        conn
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses")

      assert first_request.status == 200

      assert get_resp_header(first_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(first_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(first_request, "bypass-429-option") == ["recaptcha"]

      # Second request - should be denied with 429
      second_request =
        conn
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses")

      assert second_request.status == 429

      assert get_resp_header(second_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(second_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(second_request, "bypass-429-option") == ["recaptcha"]
    end

    test "handles temporary token bypass option", %{conn: conn} do
      config = %{
        static_match: %{
          "api/v2/transactions" => %{
            ip: %{
              period: 60_000,
              limit: 1
            },
            temporary_token: true
          }
        },
        wildcard_match: %{},
        parametrized_match: %{}
      }

      :persistent_term.put(:rate_limit_config, config)

      # First request with user agent
      first_request =
        conn
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/transactions")

      assert first_request.status == 200
      assert get_resp_header(first_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(first_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(first_request, "bypass-429-option") == ["temporary_token"]

      # Second request - should be denied with 429
      second_request =
        conn
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/transactions")

      assert second_request.status == 429
      assert get_resp_header(second_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(second_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(second_request, "bypass-429-option") == ["temporary_token"]
    end

    test "handles GraphQL requests", %{conn: conn} do
      Application.put_env(:block_scout_web, Api.GraphQL,
        rate_limit_disabled?: false,
        limit_by_ip: 1,
        time_interval_limit_by_ip: 60_000,
        global_limit: 500,
        time_interval_limit: 60_000
      )

      # First request
      first_request = conn |> post("/api/v1/graphql", %{query: "{}"})
      assert first_request.status == 200
      assert get_resp_header(first_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(first_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(first_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0

      # This request should be denied due to IP limit
      last_request = conn |> post("/api/v1/graphql", %{query: "{}"})
      assert last_request.status == 429
      assert get_resp_header(last_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(last_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(last_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0
    end

    test "handles GraphQL requests with global limit", %{conn: conn} do
      Application.put_env(:block_scout_web, Api.GraphQL,
        rate_limit_disabled?: false,
        limit_by_ip: 100,
        time_interval_limit_by_ip: 60_000,
        global_limit: 1,
        time_interval_limit: 60_000
      )

      # First request
      first_request = conn |> post("/api/v1/graphql", %{query: "{}"})
      assert first_request.status == 200
      assert get_resp_header(first_request, "x-ratelimit-limit") == ["100"]
      assert get_resp_header(first_request, "x-ratelimit-remaining") == ["99"]
      assert get_resp_header(first_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0

      # This request should be denied due to IP limit
      last_request = conn |> post("/api/v1/graphql", %{query: "{}"})
      assert last_request.status == 429
      assert get_resp_header(last_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(last_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(last_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0
    end

    test "handles parametrized paths", %{conn: conn} do
      token = insert(:token)

      config = %{
        static_match: %{},
        wildcard_match: %{},
        parametrized_match: %{
          ["api", "v2", "tokens", ":param"] => %{
            ip: %{
              period: 60_000,
              limit: 1
            }
          }
        }
      }

      :persistent_term.put(:rate_limit_config, config)

      # First request to parametrized path
      first_request = conn |> get("/api/v2/tokens/#{token.contract_address_hash}")
      assert first_request.status == 200
      assert get_resp_header(first_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(first_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(first_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0

      # Second request - should be denied with 429
      second_request = conn |> get("/api/v2/tokens/123")
      assert second_request.status == 429
      assert get_resp_header(second_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(second_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(second_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0
    end

    test "handles wildcard paths", %{conn: conn} do
      config = %{
        static_match: %{},
        wildcard_match: %{
          {["api", "v2"], 2} => %{
            ip: %{
              period: 60_000,
              limit: 1
            }
          }
        },
        parametrized_match: %{}
      }

      :persistent_term.put(:rate_limit_config, config)

      # First request to a path matching wildcard
      first_request = conn |> get("/api/v2/main-page/transactions")
      assert first_request.status == 200
      assert get_resp_header(first_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(first_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(first_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0

      # Second request - should be denied with 429
      second_request = conn |> get("/api/v2/blocks")
      assert second_request.status == 429
      assert get_resp_header(second_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(second_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(second_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0
    end

    test "falls back to default config", %{conn: conn} do
      config = %{
        static_match: %{
          "default" => %{
            ip: %{
              period: 60_000,
              limit: 1
            }
          }
        },
        wildcard_match: %{},
        parametrized_match: %{}
      }

      :persistent_term.put(:rate_limit_config, config)

      # First request to a path with no specific config
      first_request = conn |> get("/api/v2/transactions")
      assert first_request.status == 200
      assert get_resp_header(first_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(first_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(first_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0

      # Second request - should be denied with 429
      second_request = conn |> get("/api/v2/blocks")
      assert second_request.status == 429
      assert get_resp_header(second_request, "x-ratelimit-limit") == ["1"]
      assert get_resp_header(second_request, "x-ratelimit-remaining") == ["0"]
      assert get_resp_header(second_request, "x-ratelimit-reset") |> hd() |> String.to_integer() > 0
    end
  end
end
