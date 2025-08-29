defmodule Explorer.Market.MarketHistoryTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Market.MarketHistory

  describe "bulk_insert/1" do
    test "replaces existing records" do
      records = [
        %{date: ~D[2023-01-01], opening_price: Decimal.new("100.00"), closing_price: Decimal.new("110.00")},
        %{date: ~D[2023-01-02], opening_price: Decimal.new("7.50"), closing_price: Decimal.new("5.00")}
      ]

      assert {2, _} = MarketHistory.bulk_insert(records)

      records = [
        %{date: ~D[2023-01-01], opening_price: Decimal.new("50.00"), closing_price: Decimal.new("55.00")},
        %{date: ~D[2023-01-02], opening_price: Decimal.new("10.00"), closing_price: Decimal.new("8.00")}
      ]

      assert {2, _} = MarketHistory.bulk_insert(records)

      assert [date1, date2] = Repo.all(MarketHistory)
      assert date1.opening_price == Decimal.new("50.00")
      assert date1.closing_price == Decimal.new("55.00")
      assert date2.opening_price == Decimal.new("10.00")
      assert date2.closing_price == Decimal.new("8.00")
    end
  end

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
    MarketHistory.bulk_insert(insertable_records)
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

    MarketHistory.bulk_insert([new_record])

    fetched_record = Repo.get_by(MarketHistory, date: date)
    assert fetched_record.closing_price == old_record.closing_price
    assert fetched_record.opening_price == old_record.opening_price
  end
end
