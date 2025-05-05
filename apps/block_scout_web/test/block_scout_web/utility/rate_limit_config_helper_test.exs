defmodule BlockScoutWeb.Utility.RateLimitConfigHelperTest do
  use BlockScoutWeb.ConnCase, async: false
  alias BlockScoutWeb.Utility.RateLimitConfigHelper

  describe "fetch_config/0" do
    setup do
      # Store original config URL
      original_config = Application.get_env(:block_scout_web, :api_rate_limit)
      on_exit(fn -> Application.put_env(:block_scout_web, :api_rate_limit, original_config) end)
    end

    test "successfully fetches and parses config from URL" do
      config = %{
        "api/v2/*" => %{
          "static_api_key" => true,
          "account_api_key" => true
        }
      }

      bypass = Bypass.open()
      Application.put_env(:block_scout_web, :api_rate_limit, config_url: "http://localhost:#{bypass.port}/config")

      Bypass.expect_once(bypass, "GET", "/config", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(config))
      end)

      RateLimitConfigHelper.fetch_config()

      assert :persistent_term.get(:rate_limit_config) == %{
               wildcard_match: %{
                 {["api", "v2"], 2} => %{
                   static_api_key: true,
                   account_api_key: true
                 }
               },
               parametrized_match: %{},
               static_match: %{}
             }
    end

    test "falls back to local config when URL fetch fails" do
      bypass = Bypass.open()
      Application.put_env(:block_scout_web, :api_rate_limit, config_url: "http://localhost:#{bypass.port}/config")

      Bypass.expect_once(bypass, "GET", "/config", fn conn ->
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      end)

      RateLimitConfigHelper.fetch_config()
      # Verify that we got some config (from local file)
      assert is_map(:persistent_term.get(:rate_limit_config)[:static_match]["default"])
    end

    test "correctly categorizes different path types when fetching config" do
      config = %{
        "api/v2/*" => %{"limit" => 100},
        "api/v2/tokens/:param" => %{"limit" => 50},
        "api/v2/static" => %{"limit" => 25}
      }

      bypass = Bypass.open()
      Application.put_env(:block_scout_web, :api_rate_limit, config_url: "http://localhost:#{bypass.port}/config")

      Bypass.expect_once(bypass, "GET", "/config", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(config))
      end)

      RateLimitConfigHelper.fetch_config()
      result = :persistent_term.get(:rate_limit_config)

      assert result.wildcard_match == %{
               {["api", "v2"], 2} => %{limit: 100}
             }

      assert result.parametrized_match == %{
               ["api", "v2", "tokens", ":param"] => %{limit: 50}
             }

      assert result.static_match == %{
               "api/v2/static" => %{limit: 25}
             }
    end

    test "falls back to local config when fetching config with invalid wildcard placement" do
      config = %{
        "api/*/v2" => %{
          "ip" => %{
            "period" => "1h",
            "limit" => 100
          }
        }
      }

      bypass = Bypass.open()
      Application.put_env(:block_scout_web, :api_rate_limit, config_url: "http://localhost:#{bypass.port}/config")

      Bypass.expect_once(bypass, "GET", "/config", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(config))
      end)

      RateLimitConfigHelper.fetch_config()
      assert is_map(:persistent_term.get(:rate_limit_config)[:static_match]["default"])
    end

    test "converts time strings to milliseconds when fetching config" do
      config = %{
        "api/v2/endpoint" => %{
          "ip" => %{
            "period" => "5m",
            "limit" => 100
          }
        }
      }

      bypass = Bypass.open()
      Application.put_env(:block_scout_web, :api_rate_limit, config_url: "http://localhost:#{bypass.port}/config")

      Bypass.expect_once(bypass, "GET", "/config", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(config))
      end)

      RateLimitConfigHelper.fetch_config()
      result = :persistent_term.get(:rate_limit_config)

      # 5 minutes in milliseconds
      assert result.static_match["api/v2/endpoint"][:ip][:period] == 300_000
      # 100 requests per 5 minutes
      assert result.static_match["api/v2/endpoint"][:ip][:limit] == 100
    end

    test "falls back to local config when fetching config with invalid time format" do
      config = %{
        "api/v2/endpoint" => %{
          "ip" => %{
            "period" => "invalid"
          }
        }
      }

      bypass = Bypass.open()
      Application.put_env(:block_scout_web, :api_rate_limit, config_url: "http://localhost:#{bypass.port}/config")

      Bypass.expect_once(bypass, "GET", "/config", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(config))
      end)

      RateLimitConfigHelper.fetch_config()
      assert is_map(:persistent_term.get(:rate_limit_config)[:static_match]["default"])
    end

    test "correctly processes all reserved keywords in configuration" do
      config = %{
        "api/v2/endpoint" => %{
          "account_api_key" => true,
          "bypass_token_scope" => "test_scope",
          "cost" => 5,
          "ip" => %{
            "period" => "1h",
            "limit" => 100
          },
          "ignore" => true,
          "recaptcha_to_bypass_429" => true,
          "static_api_key" => true,
          "temporary_token" => true,
          "whitelisted_ip" => true
        }
      }

      bypass = Bypass.open()
      Application.put_env(:block_scout_web, :api_rate_limit, config_url: "http://localhost:#{bypass.port}/config")

      Bypass.expect_once(bypass, "GET", "/config", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(config))
      end)

      RateLimitConfigHelper.fetch_config()
      result = :persistent_term.get(:rate_limit_config)

      # Check that all keys are properly converted to atoms
      processed_config = result.static_match["api/v2/endpoint"]

      assert processed_config[:account_api_key] == true
      assert processed_config[:bypass_token_scope] == "test_scope"
      assert processed_config[:cost] == 5
      # 1h in milliseconds
      assert processed_config[:ip][:period] == 3_600_000
      assert processed_config[:ip][:limit] == 100
      assert processed_config[:ignore] == true
      assert processed_config[:recaptcha_to_bypass_429] == true
      assert processed_config[:static_api_key] == true
      assert processed_config[:temporary_token] == true
      assert processed_config[:whitelisted_ip] == true
    end

    test "correctly processes nested structures with reserved keywords" do
      config = %{
        "api/v2/tokens/:param" => %{
          "ip" => %{
            "period" => "5m",
            "limit" => 50
          },
          "static_api_key" => %{
            "period" => "1h",
            "limit" => 500
          },
          "whitelisted_ip" => %{
            "period" => "10m",
            "limit" => 1000
          }
        }
      }

      bypass = Bypass.open()
      Application.put_env(:block_scout_web, :api_rate_limit, config_url: "http://localhost:#{bypass.port}/config")

      Bypass.expect_once(bypass, "GET", "/config", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(config))
      end)

      RateLimitConfigHelper.fetch_config()
      result = :persistent_term.get(:rate_limit_config)

      # Check processing of parametrized path with nested config
      processed_config = result.parametrized_match[["api", "v2", "tokens", ":param"]]

      # Check nested IP config
      # 5m in milliseconds
      assert processed_config[:ip][:period] == 300_000
      assert processed_config[:ip][:limit] == 50

      # Check nested static_api_key config
      # 1h in milliseconds
      assert processed_config[:static_api_key][:period] == 3_600_000
      assert processed_config[:static_api_key][:limit] == 500

      # Check nested whitelisted_ip config
      # 10m in milliseconds
      assert processed_config[:whitelisted_ip][:period] == 600_000
      assert processed_config[:whitelisted_ip][:limit] == 1000
    end

    test "handles unsupported keywords gracefully" do
      config = %{
        "api/v2/endpoint" => %{
          "unknown_keyword" => true,
          "another_unknown" => "value",
          "ip" => %{
            "period" => "1h",
            "limit" => 100,
            "unsupported_nested" => "test"
          }
        }
      }

      bypass = Bypass.open()
      Application.put_env(:block_scout_web, :api_rate_limit, config_url: "http://localhost:#{bypass.port}/config")

      Bypass.expect_once(bypass, "GET", "/config", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(config))
      end)

      RateLimitConfigHelper.fetch_config()
      result = :persistent_term.get(:rate_limit_config)

      processed_config = result.static_match["api/v2/endpoint"]

      # It should process the supported keywords while ignoring unsupported ones
      # 1h in milliseconds
      assert processed_config[:ip][:period] == 3_600_000
      assert processed_config[:ip][:limit] == 100

      # Verify unsupported keywords are not included or are handled gracefully
      assert processed_config["unknown_keyword"] == true
      assert processed_config["another_unknown"] == "value"
      assert processed_config[:ip]["unsupported_nested"] == "test"
    end
  end
end
