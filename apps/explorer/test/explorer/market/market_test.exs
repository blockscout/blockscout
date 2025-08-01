defmodule Explorer.MarketTest do
  use Explorer.DataCase, async: false

  alias Explorer.Market
  alias Explorer.Market.MarketHistory
  alias Explorer.Repo

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())

    on_exit(fn ->
      Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
      Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    end)

    :ok
  end

  test "fetch_recent_history/1" do
    ConCache.delete(:market_history, :last_update)

    today = Date.utc_today()

    records =
      for i <- 0..29 do
        %{
          date: Timex.shift(today, days: i * -1),
          closing_price: Decimal.new(1),
          opening_price: Decimal.new(1)
        }
      end

    MarketHistory.bulk_insert(records)

    history = Market.fetch_recent_history()
    assert length(history) == 30
    assert Enum.at(history, 0).date == Enum.at(records, 0).date
  end
end
