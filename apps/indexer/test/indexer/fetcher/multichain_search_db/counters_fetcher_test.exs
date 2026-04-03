defmodule Indexer.Fetcher.MultichainSearchDb.CountersFetcherTest do
  use ExUnit.Case
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias Explorer.Chain.MultichainSearchDb.CountersExportQueue
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Transaction.History.{Historian, TransactionStats}
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Repo
  alias Indexer.Fetcher.MultichainSearchDb.CountersFetcher

  @moduletag :capture_log

  setup do
    previous_multichain_config = Application.get_env(:explorer, MultichainSearch)

    Application.put_env(:explorer, MultichainSearch,
      service_url: "http://localhost:1234",
      api_key: "12345",
      counters_chunk_size: 1000
    )

    on_exit(fn ->
      Application.put_env(:explorer, MultichainSearch, previous_multichain_config)
    end)

    :ok
  end

  describe "handle_info/2" do
    test "waits until transaction stats are collected for today" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      :ok = put_last_save_records_date(yesterday)

      log =
        capture_log(fn ->
          assert {:noreply, %{}} = CountersFetcher.handle_info(:try_to_fetch_yesterday_counters, %{})
        end)

      assert Repo.aggregate(CountersExportQueue, :count) == 0
      refute_received :fetch_yesterday_counters
      assert log =~ "Waiting for transaction stats to be collected for #{yesterday}"
    end

    test "queues yesterday counters once transaction stats are ready" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      yesterday_dt = DateTime.new!(yesterday, Time.new!(23, 59, 59, 0))

      :ok = put_last_save_records_date(today)

      Repo.insert_all(TransactionStats, [
        %{date: yesterday, number_of_transactions: 7}
      ])

      insert(:address, inserted_at: DateTime.add(yesterday_dt, -3600, :second))
      insert(:address, inserted_at: DateTime.add(yesterday_dt, -1800, :second))
      insert(:address, inserted_at: DateTime.add(yesterday_dt, 2, :second))

      past_block = insert(:block, timestamp: DateTime.add(yesterday_dt, -900, :second), consensus: true)
      future_block = insert(:block, timestamp: DateTime.add(yesterday_dt, 2, :second), consensus: true)
      non_consensus_block = insert(:block, timestamp: DateTime.add(yesterday_dt, -600, :second), consensus: false)

      insert(:transaction)
      |> with_block(past_block, block_timestamp: past_block.timestamp, block_consensus: true, status: :ok)

      insert(:transaction)
      |> with_block(past_block, block_timestamp: past_block.timestamp, block_consensus: true, status: :ok)

      insert(:transaction)
      |> with_block(future_block, block_timestamp: future_block.timestamp, block_consensus: true, status: :ok)

      insert(:transaction,
        block_hash: non_consensus_block.hash,
        block_number: non_consensus_block.number,
        block_timestamp: non_consensus_block.timestamp,
        block_consensus: false,
        cumulative_gas_used: 21_000,
        gas_used: 21_000,
        index: 0,
        status: :ok
      )

      log =
        capture_log(fn ->
          assert {:noreply, %{number_of_transactions: 7, yesterday: ^yesterday}} =
                   CountersFetcher.handle_info(:try_to_fetch_yesterday_counters, %{})

          assert_receive :fetch_yesterday_counters

          assert {:noreply, %{}} =
                   CountersFetcher.handle_info(:fetch_yesterday_counters, %{
                     number_of_transactions: 7,
                     yesterday: yesterday
                   })
        end)

      assert [queued_counter] = Repo.all(CountersExportQueue)

      assert queued_counter.timestamp == yesterday_dt
      assert queued_counter.counter_type == :global

      assert queued_counter.data == %{
               "daily_transactions_number" => "7",
               "total_transactions_number" => "2",
               "total_addresses_number" => "2"
             }

      assert log =~ "Transaction stats is now available for #{yesterday}"
      assert log =~ "daily_transactions_number = 7"
      assert log =~ "total_transactions_number = 2"
      assert log =~ "total_addresses_number = 2"
    end
  end

  defp put_last_save_records_date(date) do
    date
    |> DateTime.new!(Time.new!(0, 0, 0, 0))
    |> DateTime.to_unix()
    |> then(fn unix_timestamp ->
      LastFetchedCounter.upsert(%{
        counter_type: Historian.transaction_stats_last_save_records_timestamp(),
        value: unix_timestamp
      })
    end)
    |> case do
      {:ok, _counter} -> :ok
      {:error, error} -> raise inspect(error)
    end
  end
end
