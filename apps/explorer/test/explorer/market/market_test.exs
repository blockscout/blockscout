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
    today = Date.utc_today()

    records =
      for i <- 0..29 do
        %{
          date: Timex.shift(today, days: i * -1),
          closing_price: Decimal.new(1),
          opening_price: Decimal.new(1)
        }
      end

    Market.bulk_insert_history(records)

    history = Market.fetch_recent_history()
    assert length(history) == 30
    assert Enum.at(history, 0).date == Enum.at(records, 0).date
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

    test "doesn't replace existing records with zeros" do
      date = ~D[2018-04-01]

      {:ok, old_record} =
        Repo.insert(%MarketHistory{date: date, closing_price: Decimal.new(1), opening_price: Decimal.new(1)})

      new_record = %{
        date: date,
        closing_price: Decimal.new(0),
        opening_price: Decimal.new(0)
      }

      Market.bulk_insert_history([new_record])

      fetched_record = Repo.get_by(MarketHistory, date: date)
      assert fetched_record.closing_price == old_record.closing_price
      assert fetched_record.opening_price == old_record.opening_price
    end

    test "does not override existing records on date conflict" do
      date = ~D[2018-04-01]

      {:ok, old_record} =
        Repo.insert(%MarketHistory{date: date, closing_price: Decimal.new(2), opening_price: Decimal.new(2)})

      new_record = %{
        date: date,
        closing_price: Decimal.new(1),
        opening_price: Decimal.new(1)
      }

      Market.bulk_insert_history([new_record])

      fetched_record = Repo.get_by(MarketHistory, date: date)
      assert fetched_record.closing_price == old_record.closing_price
      assert fetched_record.opening_price == old_record.opening_price
    end
  end
end
