defmodule Explorer.Utility.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Explorer.Utility.RateLimiter

  setup do
    RateLimiter.start_link([])

    init_config = Application.get_env(:explorer, RateLimiter)
    Application.put_env(:explorer, RateLimiter, Keyword.put(init_config, :enabled, true))

    on_exit(fn ->
      Application.put_env(:explorer, RateLimiter, init_config)
    end)
  end

  test "ban identifier from action if it exceeds rate limit" do
    config = Application.get_env(:explorer, RateLimiter)

    updated_config =
      Keyword.put(
        config,
        :on_demand,
        Keyword.merge(config[:on_demand], time_interval_limit: 1000, limit_by_ip: 1, exp_timeout_coeff: 1)
      )

    Application.put_env(:explorer, RateLimiter, updated_config)

    assert RateLimiter.check_rate("test", :on_demand) == :allow
    now = :os.system_time(:second)
    assert RateLimiter.check_rate("test", :on_demand) == :deny
    assert RateLimiter.check_rate("test", :on_demand) == :deny

    expected_ban_data = "#{now + 1}:1"
    assert [{"test_on_demand", ^expected_ban_data}] = :ets.lookup(:rate_limiter, "test_on_demand")

    Process.sleep(2000)

    assert RateLimiter.check_rate("test", :on_demand) == :allow
    now = :os.system_time(:second)
    assert RateLimiter.check_rate("test", :on_demand) == :deny
    assert RateLimiter.check_rate("test", :on_demand) == :deny

    expected_ban_data = "#{now + 2}:2"
    assert [{"test_on_demand", ^expected_ban_data}] = :ets.lookup(:rate_limiter, "test_on_demand")
  end
end
