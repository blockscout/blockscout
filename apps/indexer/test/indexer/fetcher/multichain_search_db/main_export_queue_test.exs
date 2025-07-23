defmodule Indexer.Fetcher.MultichainSearchDb.MainExportQueueTest do
  use ExUnit.Case
  use Explorer.DataCase

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias Explorer.Chain.MultichainSearchDb.MainExportQueue
  alias Explorer.Chain.Block.Range
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.TestHelper
  alias Indexer.Fetcher.MultichainSearchDb.MainExportQueue, as: MultichainSearchDbMainExportQueue
  alias Plug.Conn

  @moduletag :capture_log

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    Application.put_env(:indexer, MultichainSearchDbMainExportQueue.Supervisor, disabled?: false)

    on_exit(fn ->
      Application.put_env(:indexer, MultichainSearchDbMainExportQueue.Supervisor, disabled?: true)
    end)

    :ok
  end

  describe "init/3" do
    setup do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        addresses_chunk_size: 7000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
      end)
    end

    test "initializes with data from the retry queue" do
      address_hash_bytes = "66A9B160F6a06f53f23785F069882Ee7337180E8" |> Base.decode16!(case: :mixed)

      block_hash_bytes =
        "bba915260f4859d2c908d31296e125368c01e05ee59e2e691ea8d69cceac6e1b" |> Base.decode16!(case: :mixed)

      transaction_hash_bytes =
        "aba197aa8a13871bdd53861f7b5108394000fc0f72893661ae39610e9cd94019" |> Base.decode16!(case: :mixed)

      insert(:multichain_search_db_main_export_queue, %{hash: address_hash_bytes, hash_type: :address})
      insert(:multichain_search_db_main_export_queue, %{hash: block_hash_bytes, hash_type: :block})
      insert(:multichain_search_db_main_export_queue, %{hash: transaction_hash_bytes, hash_type: :transaction})

      reducer = fn data, acc -> [data | acc] end

      pid =
        []
        |> MultichainSearchDbMainExportQueue.Supervisor.child_spec()
        |> ExUnit.Callbacks.start_supervised!()

      results = MultichainSearchDbMainExportQueue.init([], reducer, nil)

      assert Enum.count(results) == 3
      assert Enum.member?(results, %{hash: address_hash_bytes, hash_type: :address, block_range: nil})
      assert Enum.member?(results, %{hash: block_hash_bytes, hash_type: :block, block_range: nil})
      assert Enum.member?(results, %{hash: transaction_hash_bytes, hash_type: :transaction, block_range: nil})
      :timer.sleep(10)
      GenServer.stop(pid)
    end
  end

  describe "run/2" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        addresses_chunk_size: 7000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
        Bypass.down(bypass)
      end)

      {:ok, bypass: bypass}
    end

    test "successfully processes multichain search db export retry queue data", %{bypass: bypass} do
      address_hash_bytes = "66A9B160F6a06f53f23785F069882Ee7337180E8" |> Base.decode16!(case: :mixed)

      block_hash_bytes =
        "bba915260f4859d2c908d31296e125368c01e05ee59e2e691ea8d69cceac6e1b" |> Base.decode16!(case: :mixed)

      transaction_hash_bytes =
        "aba197aa8a13871bdd53861f7b5108394000fc0f72893661ae39610e9cd94019" |> Base.decode16!(case: :mixed)

      export_data = [
        %{hash: address_hash_bytes, hash_type: :address, block_range: nil},
        %{hash: block_hash_bytes, hash_type: :block, block_range: nil},
        %{hash: transaction_hash_bytes, hash_type: :transaction, block_range: nil}
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

      assert :ok = MultichainSearchDbMainExportQueue.run(export_data, nil)
    end

    test "returns {:retry, failed_data} on error where failed_data is only chunks that failed to export", %{
      bypass: _bypass
    } do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        addresses_chunk_size: 1
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
      end)

      address_1 = insert(:address)
      address_1_hash_string = to_string(address_1) |> String.downcase()
      address_2 = insert(:address)
      address_2_hash_string = to_string(address_2) |> String.downcase()
      address_3 = insert(:address)
      block = insert(:block, number: 1)
      block_number_string = to_string(block.number)
      block_hash_string = to_string(block.hash)
      transaction = insert(:transaction) |> with_block(block)
      transaction_hash_string = to_string(transaction.hash)

      export_data = [
        %{hash: address_1.hash.bytes, hash_type: :address, block_range: %Range{from: block.number, to: block.number}},
        %{hash: address_2.hash.bytes, hash_type: :address, block_range: %Range{from: block.number, to: block.number}},
        %{hash: address_3.hash.bytes, hash_type: :address, block_range: %Range{from: block.number, to: block.number}},
        %{hash: block.hash.bytes, hash_type: :block, block_range: %Range{from: block.number, to: block.number}},
        %{
          hash: transaction.hash.bytes,
          hash_type: :transaction,
          block_range: %Range{from: block.number, to: block.number}
        }
      ]

      TestHelper.get_chain_id_mock()

      Tesla.Test.expect_tesla_call(
        times: 3,
        returns: fn %{url: "http://localhost:1234/api/v1/import:batch", body: body}, _opts ->
          case Jason.decode(body) do
            {:ok, %{"block_ranges" => [%{"max_block_number" => _, "min_block_number" => _}]}} ->
              {:ok, %Tesla.Env{status: 500, body: Jason.encode!(%{"code" => 0, "message" => "Error"})}}

            {:ok, %{"addresses" => [%{"hash" => ^address_2_hash_string}]}} ->
              {:ok, %Tesla.Env{status: 500, body: Jason.encode!(%{"code" => 0, "message" => "Error"})}}

            _ ->
              {:ok, %Tesla.Env{status: 200, body: Jason.encode!(%{"status" => "ok"})}}
          end
        end
      )

      log =
        capture_log(fn ->
          assert {:retry,
                  %{
                    addresses: [
                      %{
                        hash: ^address_2_hash_string,
                        token_type: "UNSPECIFIED",
                        is_contract: false,
                        token_name: nil,
                        contract_name: nil,
                        ens_name: nil,
                        is_token: false,
                        is_verified_contract: false
                      },
                      %{
                        hash: ^address_1_hash_string,
                        token_type: "UNSPECIFIED",
                        is_contract: false,
                        token_name: nil,
                        contract_name: nil,
                        ens_name: nil,
                        is_token: false,
                        is_verified_contract: false
                      }
                    ],
                    block_ranges: [%{max_block_number: ^block_number_string, min_block_number: ^block_number_string}],
                    hashes: [
                      %{hash: ^block_hash_string, hash_type: "BLOCK"},
                      %{
                        hash: ^transaction_hash_string,
                        hash_type: "TRANSACTION"
                      }
                    ]
                  }} = MultichainSearchDbMainExportQueue.run(export_data, nil)
        end)

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 4
      results = Repo.all(MainExportQueue)
      assert Enum.all?(results, &(&1.retries_number == nil))

      assert log =~ "Batch main export retry to the Multichain Search DB failed"

      export_data_2 = [
        %{hash: address_2.hash.bytes, hash_type: :address, block_range: %Range{from: block.number, to: block.number}},
        %{hash: address_1.hash.bytes, hash_type: :address, block_range: %Range{from: block.number, to: block.number}},
        %{hash: block.hash.bytes, hash_type: :block, block_range: %Range{from: block.number, to: block.number}},
        %{
          hash: transaction.hash.bytes,
          hash_type: :transaction,
          block_range: %Range{from: block.number, to: block.number}
        }
      ]

      TestHelper.get_chain_id_mock()

      tesla_expectations()

      MultichainSearchDbMainExportQueue.run(export_data_2, nil)

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 3
      results = Repo.all(MainExportQueue)
      assert Enum.all?(results, &(&1.retries_number == 1))

      # Check, that `retries_number` is incrementing

      TestHelper.get_chain_id_mock()

      tesla_expectations()

      MultichainSearchDbMainExportQueue.run(export_data_2, nil)

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 3
      results = Repo.all(MainExportQueue)
      assert Enum.all?(results, &(&1.retries_number == 2))
    end
  end

  defp tesla_expectations() do
    Tesla.Test.expect_tesla_call(
      times: 2,
      returns: fn %{url: "http://localhost:1234/api/v1/import:batch", body: body}, _opts ->
        case Jason.decode(body) do
          {:ok, %{"block_ranges" => [%{"max_block_number" => _, "min_block_number" => _}]}} ->
            {:ok, %Tesla.Env{status: 500, body: Jason.encode!(%{"code" => 0, "message" => "Error"})}}

          _ ->
            {:ok, %Tesla.Env{status: 200, body: Jason.encode!(%{"status" => "ok"})}}
        end
      end
    )
  end
end
