defmodule Explorer.ExchangeRatesTest do
  use ExUnit.Case, async: false

  import Mox

  alias Explorer.ExchangeRates
  alias Explorer.ExchangeRates.Token
  alias Explorer.ExchangeRates.Source.TestSource

  @moduletag :capture_log

  setup :verify_on_exit!

  setup do
    # Use TestSource mock and ets table for this test set
    configuration = Application.get_env(:explorer, Explorer.ExchangeRates)
    Application.put_env(:explorer, Explorer.ExchangeRates, source: TestSource)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.ExchangeRates, configuration)
    end)
  end

  test "start_link" do
    stub(TestSource, :fetch_exchange_rates, fn -> {:ok, [Token.null()]} end)
    set_mox_global()

    assert {:ok, _} = ExchangeRates.start_link([])
  end

  test "init" do
    assert :ets.info(ExchangeRates.table_name()) == :undefined

    assert {:ok, %{}} == ExchangeRates.init([])
    assert_received :update
    table = :ets.info(ExchangeRates.table_name())
    refute table == :undefined
    assert table[:name] == ExchangeRates.table_name()
    assert table[:named_table]
    assert table[:read_concurrency]
    assert table[:type] == :set
    assert table[:write_concurrency]
  end

  test "handle_info with :update" do
    ExchangeRates.init([])
    state = %{}

    expect(TestSource, :fetch_exchange_rates, fn -> {:ok, [Token.null()]} end)
    set_mox_global()

    assert {:noreply, ^state} = ExchangeRates.handle_info(:update, state)
    assert_receive {_, {:ok, [%Token{}]}}
  end

  describe "ticker fetch task" do
    setup do
      ExchangeRates.init([])
      :ok
    end

    test "with successful fetch" do
      expected_token = %Token{
        available_supply: Decimal.new("1000000.0"),
        btc_value: Decimal.new("1.000"),
        id: "test_id",
        last_updated: DateTime.utc_now(),
        market_cap_usd: Decimal.new("1000000.0"),
        name: "test_name",
        symbol: "test_symbol",
        usd_value: Decimal.new("1.0"),
        volume_24h_usd: Decimal.new("1000.0")
      }

      expected_symbol = expected_token.symbol
      expected_tuple = Token.to_tuple(expected_token)

      state = %{}

      assert {:noreply, ^state} = ExchangeRates.handle_info({nil, {:ok, [expected_token]}}, state)

      assert [^expected_tuple] = :ets.lookup(ExchangeRates.table_name(), expected_symbol)
    end

    test "with failed fetch" do
      state = %{}

      expect(TestSource, :fetch_exchange_rates, fn -> {:ok, [Token.null()]} end)
      set_mox_global()

      assert {:noreply, ^state} = ExchangeRates.handle_info({nil, {:error, "some error"}}, state)

      assert_receive {_, {:ok, _}}
    end
  end

  test "list/0" do
    ExchangeRates.init([])

    rates = [
      %Token{Token.null() | symbol: "z"},
      %Token{Token.null() | symbol: "a"}
    ]

    expected_rates = Enum.reverse(rates)
    for rate <- rates, do: :ets.insert(ExchangeRates.table_name(), Token.to_tuple(rate))

    assert expected_rates == ExchangeRates.list()
  end

  test "lookup/1" do
    ExchangeRates.init([])

    z = %Token{Token.null() | symbol: "z"}

    rates = [z, %Token{Token.null() | symbol: "a"}]

    for rate <- rates, do: :ets.insert(ExchangeRates.table_name(), Token.to_tuple(rate))

    assert z == ExchangeRates.lookup("z")
    assert nil == ExchangeRates.lookup("nope")
  end
end
