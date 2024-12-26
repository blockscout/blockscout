defmodule BlockScoutWeb.AccessHelperTest do
  alias BlockScoutWeb.AccessHelper
  use BlockScoutWeb.ConnCase
  import Mox

  setup :verify_on_exit!

  setup do
    configuration = Application.get_env(:block_scout_web, :api_rate_limit)

    on_exit(fn ->
      Application.put_env(:block_scout_web, :api_rate_limit, configuration)
    end)

    :ok
  end

  describe "check_rate_limit/1" do
    test "rate_limit_disabled", %{conn: conn} do
      Application.put_env(:block_scout_web, :api_rate_limit,
        global_limit: 0,
        limit_by_key: 0,
        limit_by_whitelisted_ip: 0,
        time_interval_limit: 1_000,
        disabled: true
      )

      assert AccessHelper.check_rate_limit(conn) == :ok
    end

    test "no_rate_limit_api_key", %{conn: conn} do
      Application.put_env(:block_scout_web, :api_rate_limit,
        global_limit: 0,
        limit_by_key: 0,
        limit_by_whitelisted_ip: 0,
        time_interval_limit: 1_000,
        no_rate_limit_api_key: "123"
      )

      conn = %{conn | query_params: %{"apikey" => "123"}}
      assert AccessHelper.check_rate_limit(conn) == :ok
    end

    test "rate limit, if no_rate_limit_api_key is nil", %{conn: conn} do
      Application.put_env(:block_scout_web, :api_rate_limit,
        global_limit: 0,
        limit_by_key: 0,
        limit_by_whitelisted_ip: 0,
        time_interval_limit: 1_000,
        no_rate_limit_api_key: nil
      )

      conn = %{conn | query_params: %{"apikey" => nil}}
      assert AccessHelper.check_rate_limit(conn) == :rate_limit_reached
    end

    test "rate limit, if no_rate_limit_api_key is empty", %{conn: conn} do
      Application.put_env(:block_scout_web, :api_rate_limit,
        global_limit: 0,
        limit_by_key: 0,
        limit_by_whitelisted_ip: 0,
        time_interval_limit: 1_000,
        no_rate_limit_api_key: ""
      )

      conn = %{conn | query_params: %{"apikey" => "     "}}
      assert AccessHelper.check_rate_limit(conn) == :rate_limit_reached
    end
  end
end
