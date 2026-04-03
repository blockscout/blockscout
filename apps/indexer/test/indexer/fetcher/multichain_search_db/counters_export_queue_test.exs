defmodule Indexer.Fetcher.MultichainSearchDb.CountersExportQueueTest do
  use ExUnit.Case
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias Explorer.Chain.MultichainSearchDb.CountersExportQueue
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.TestHelper
  alias Explorer.Repo
  alias Indexer.Fetcher.MultichainSearchDb.CountersExportQueue, as: MultichainSearchDbCountersExportQueue
  alias Plug.Conn

  @moduletag :capture_log

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    previous_supervisor_config =
      Application.get_env(:indexer, MultichainSearchDbCountersExportQueue.Supervisor)

    Application.put_env(:indexer, MultichainSearchDbCountersExportQueue.Supervisor, disabled?: false)

    on_exit(fn ->
      Application.put_env(
        :indexer,
        MultichainSearchDbCountersExportQueue.Supervisor,
        previous_supervisor_config
      )
    end)

    :ok
  end

  describe "init/3" do
    setup do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        counters_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, counters_chunk_size: 1000)
      end)
    end

    test "initializes with data from the retry queue" do
      counter_item_1 =
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(1), data: counter_data("10"))

      counter_item_2 =
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(2), data: counter_data("20"))

      counter_item_3 =
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(3), data: counter_data("30"))

      reducer = fn data, acc -> [data | acc] end

      pid =
        []
        |> MultichainSearchDbCountersExportQueue.Supervisor.child_spec()
        |> ExUnit.Callbacks.start_supervised!()

      results = MultichainSearchDbCountersExportQueue.init([], reducer, nil)

      assert Enum.count(results) == 3

      assert Enum.member?(results, %{
               timestamp: counter_item_1.timestamp,
               counter_type: counter_item_1.counter_type,
               data: counter_item_1.data
             })

      assert Enum.member?(results, %{
               timestamp: counter_item_2.timestamp,
               counter_type: counter_item_2.counter_type,
               data: counter_item_2.data
             })

      assert Enum.member?(results, %{
               timestamp: counter_item_3.timestamp,
               counter_type: counter_item_3.counter_type,
               data: counter_item_3.data
             })

      :timer.sleep(100)
      GenServer.stop(pid)
    end
  end

  describe "run/2" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        counters_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, counters_chunk_size: 1000)
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
        Bypass.down(bypass)
      end)

      {:ok, bypass: bypass}
    end

    test "successfully processes multichain search db export counters retry queue data", %{bypass: bypass} do
      export_data = [
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(1), data: counter_data("10")),
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(2), data: counter_data("20")),
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(3), data: counter_data("30"))
      ]

      TestHelper.get_chain_id_mock()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Bypass.expect_once(bypass, "POST", "/api/v1/import:batch", fn conn ->
        Conn.resp(
          conn,
          200,
          Jason.encode!(%{"status" => "ok"})
        )
      end)

      assert :ok = MultichainSearchDbCountersExportQueue.run(export_data, nil)
      assert Repo.aggregate(CountersExportQueue, :count) == 0
    end

    test "returns {:retry, failed_data} on error where failed_data is only chunks that failed to export" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        counters_chunk_size: 1
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, counters_chunk_size: 1000)
      end)

      counter_item_1 =
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(1), data: counter_data("10"))

      counter_item_2 =
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(2), data: counter_data("20"))

      counter_item_3 =
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(3), data: counter_data("30"))

      counter_item_4 =
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(4), data: counter_data("40"))

      counter_item_5 =
        insert(:multichain_search_db_export_counters_queue, timestamp: counter_timestamp(5), data: counter_data("50"))

      export_data = [counter_item_1, counter_item_2, counter_item_3, counter_item_4, counter_item_5]
      failed_timestamp_string = Integer.to_string(DateTime.to_unix(counter_item_4.timestamp))

      TestHelper.get_chain_id_mock()

      tesla_expectations(failed_timestamp_string, 5)

      log =
        capture_log(fn ->
          assert {:retry, [item_to_retry]} = MultichainSearchDbCountersExportQueue.run(export_data, nil)

          assert item_to_retry.timestamp == counter_item_4.timestamp
          assert item_to_retry.counter_type == counter_item_4.counter_type
          assert item_to_retry.data == counter_item_4.data
        end)

      assert Repo.aggregate(CountersExportQueue, :count) == 1
      assert [remaining_item] = Repo.all(CountersExportQueue)
      assert remaining_item.retries_number == 1
      assert log =~ "Batch counters export attempt to the Multichain Search DB failed"

      TestHelper.get_chain_id_mock()

      tesla_expectations(failed_timestamp_string, 1)

      MultichainSearchDbCountersExportQueue.run([counter_item_4], nil)

      assert Repo.aggregate(CountersExportQueue, :count) == 1
      assert [remaining_item] = Repo.all(CountersExportQueue)
      assert remaining_item.retries_number == 2

      TestHelper.get_chain_id_mock()

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "http://localhost:1234/api/v1/import:batch"}, _opts ->
          {:ok, %Tesla.Env{status: 200, body: Jason.encode!(%{"status" => "ok"})}}
        end
      )

      assert :ok = MultichainSearchDbCountersExportQueue.run([counter_item_4], nil)
      assert Repo.aggregate(CountersExportQueue, :count) == 0
    end
  end

  defp tesla_expectations(failed_timestamp_string, times) do
    Tesla.Test.expect_tesla_call(
      times: times,
      returns: fn %{url: "http://localhost:1234/api/v1/import:batch", body: body}, _opts ->
        case Jason.decode(body) do
          {:ok, %{"counters" => [%{"timestamp" => ^failed_timestamp_string}]}} ->
            {:ok, %Tesla.Env{status: 500, body: Jason.encode!(%{"code" => 0, "message" => "Error"})}}

          _ ->
            {:ok, %Tesla.Env{status: 200, body: Jason.encode!(%{"status" => "ok"})}}
        end
      end
    )
  end

  defp counter_timestamp(offset_in_seconds) do
    DateTime.from_unix!(1_700_000_000 + offset_in_seconds)
  end

  defp counter_data(value) do
    %{
      "daily_transactions_number" => value,
      "total_transactions_number" => Integer.to_string(String.to_integer(value) * 10),
      "total_addresses_number" => Integer.to_string(String.to_integer(value) * 100)
    }
  end
end
