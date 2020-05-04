defmodule Explorer.Chain.Transaction.History.HistorianTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Transaction.History.Historian
  alias Explorer.Chain.Transaction.History.TransactionStats

  import Ecto.Query, only: [from: 2]

  setup do
    Application.put_env(:explorer, Historian, utc_today: ~D[1970-01-04])
    :ok
  end

  defp days_to_secs(days) do
    60 * 60 * 24 * days
  end

  describe "compile_records/1" do
    test "fetches transactions from blocks mined in the past num_days" do
      blocks = [
        # 1970-01-03 00:00:60
        insert(:block, timestamp: DateTime.from_unix!(days_to_secs(2) + 60)),

        # 1970-01-03 04:00:00
        insert(:block, timestamp: DateTime.from_unix!(days_to_secs(2) + 4 * 60 * 60)),

        # 1970-01-02 00:00:00
        insert(:block, timestamp: DateTime.from_unix!(days_to_secs(1)))
      ]

      insert(:transaction) |> with_block(Enum.at(blocks, 0))
      insert(:transaction) |> with_block(Enum.at(blocks, 1))
      insert(:transaction) |> with_block(Enum.at(blocks, 2))

      expected = [
        %{date: ~D[1970-01-04], number_of_transactions: 0}
      ]

      assert {:ok, ^expected} = Historian.compile_records(1)

      expected = [
        %{date: ~D[1970-01-04], number_of_transactions: 0},
        %{date: ~D[1970-01-03], number_of_transactions: 2}
      ]

      assert {:ok, ^expected} = Historian.compile_records(2)

      expected = [
        %{date: ~D[1970-01-04], number_of_transactions: 0},
        %{date: ~D[1970-01-03], number_of_transactions: 2},
        %{date: ~D[1970-01-02], number_of_transactions: 1}
      ]

      assert {:ok, ^expected} = Historian.compile_records(3)
    end
  end

  describe "save_records/1" do
    test "saves transaction history records" do
      records = [
        %{date: ~D[1970-01-04], number_of_transactions: 3},
        %{date: ~D[1970-01-03], number_of_transactions: 2},
        %{date: ~D[1970-01-02], number_of_transactions: 1}
      ]

      Historian.save_records(records)

      records = List.replace_at(records, 0, Map.put(Enum.at(records, 0), :number_of_transactions, 4))
      single_record = [Enum.at(records, 0)]

      Historian.save_records(single_record)

      query =
        from(stats in TransactionStats,
          select: %{date: stats.date, number_of_transactions: stats.number_of_transactions},
          order_by: [desc: stats.date]
        )

      results = Repo.all(query)

      assert 3 == length(results)
      assert ^records = results
    end

    test "overwrites records with the same date without error" do
      records = [%{date: ~D[1970-01-04], number_of_transactions: 3}]
      Historian.save_records(records)
      records = [%{date: ~D[1970-01-04], number_of_transactions: 1}]
      Historian.save_records(records)
    end
  end

  @tag capture_log: true
  test "start_link" do
    assert {:ok, _} = Historian.start_link([])
  end
end
