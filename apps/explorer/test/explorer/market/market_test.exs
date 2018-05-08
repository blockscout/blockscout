defmodule Explorer.MarketTest do
  use Explorer.DataCase

  alias Explorer.ExchangeRates
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market
  alias Explorer.Market.MarketHistory
  alias Explorer.Repo

  describe "fetch_exchange_rate/1" do
    setup do
      {:ok, _} = ExchangeRates.start_link([])
      rate = %Token{id: "POA", symbol: "POA"}
      :ets.insert(ExchangeRates.table_name(), {rate.id, rate})
      {:ok, %{rate: rate}}
    end

    test "with matching symbol", %{rate: rate} do
      assert Market.fetch_exchange_rate("POA") == rate
    end

    test "with no matching symbol" do
      assert Market.fetch_exchange_rate("ETH") == nil
    end
  end

  test "fetch_recent_history/1" do
    today = Date.utc_today()

    records =
      for i <- 0..5 do
        %{
          date: Timex.shift(today, days: i * -1),
          closing_price: Decimal.new(1),
          opening_price: Decimal.new(1)
        }
      end

    Market.bulk_insert_history(records)

    history = Market.fetch_recent_history(1)
    assert length(history) == 1
    assert Enum.at(history, 0).date == Enum.at(records, 0).date

    more_history = Market.fetch_recent_history(5)
    assert length(more_history) == 5

    for {history_record, index} <- Enum.with_index(more_history) do
      assert history_record.date == Enum.at(records, index).date
    end
  end

  describe "bulk_insert_history/1" do
    test "inserts records" do
      comparable_values = %{
        ~D[2018-04-01] => %{
          date: ~D[2018-04-01],
          closing_price: Decimal.new(1),
          opening_price: Decimal.new(1)
        },
        ~D[2018-04-02] => %{
          date: ~D[2018-04-02],
          closing_price: Decimal.new(1),
          opening_price: Decimal.new(1)
        },
        ~D[2018-04-03] => %{
          date: ~D[2018-04-03],
          closing_price: Decimal.new(1),
          opening_price: Decimal.new(1)
        }
      }

      insertable_records = Map.values(comparable_values)
      Market.bulk_insert_history(insertable_records)
      history = Repo.all(MarketHistory)

      missing_records =
        Enum.reduce(history, comparable_values, fn record, acc ->
          initial_record = Map.get(acc, record.date)
          assert record.date == initial_record.date
          assert record.closing_price == initial_record.closing_price
          assert record.opening_price == initial_record.opening_price
          Map.delete(acc, record.date)
        end)

      assert missing_records == %{}
    end

    test "overrides existing records on date conflict" do
      date = ~D[2018-04-01]
      Repo.insert(%MarketHistory{date: date})

      new_record = %{
        date: date,
        closing_price: Decimal.new(1),
        opening_price: Decimal.new(1)
      }

      Market.bulk_insert_history([new_record])

      fetched_record = Repo.get_by(MarketHistory, date: date)
      assert fetched_record.closing_price == new_record.closing_price
      assert fetched_record.opening_price == new_record.opening_price
    end
  end
end
