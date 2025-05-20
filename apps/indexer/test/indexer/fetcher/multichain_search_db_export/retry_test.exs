defmodule Indexer.Fetcher.MultichainSearchDbExport.RetryTest do
  use ExUnit.Case
  use Explorer.DataCase

  import ExUnit.CaptureLog, only: [capture_log: 1]
  import Mox

  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.TestHelper
  alias Indexer.Fetcher.MultichainSearchDbExport.Retry, as: MultichainSearchDbExportRetry
  alias Plug.Conn

  @moduletag :capture_log

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    Application.put_env(:indexer, MultichainSearchDbExportRetry.Supervisor, disabled?: false)

    on_exit(fn ->
      Application.put_env(:indexer, MultichainSearchDbExportRetry.Supervisor, disabled?: true)
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

      insert(:multichain_search_db_export_retry_queue, %{hash: address_hash_bytes, hash_type: :address})
      insert(:multichain_search_db_export_retry_queue, %{hash: block_hash_bytes, hash_type: :block})
      insert(:multichain_search_db_export_retry_queue, %{hash: transaction_hash_bytes, hash_type: :transaction})

      reducer = fn data, acc -> [data | acc] end

      pid =
        []
        |> MultichainSearchDbExportRetry.Supervisor.child_spec()
        |> ExUnit.Callbacks.start_supervised!()

      results = MultichainSearchDbExportRetry.init([], reducer, nil)

      assert Enum.count(results) == 3
      assert Enum.member?(results, %{hash: address_hash_bytes, hash_type: :address})
      assert Enum.member?(results, %{hash: block_hash_bytes, hash_type: :block})
      assert Enum.member?(results, %{hash: transaction_hash_bytes, hash_type: :transaction})
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
        %{hash: address_hash_bytes, hash_type: :address},
        %{hash: block_hash_bytes, hash_type: :block},
        %{hash: transaction_hash_bytes, hash_type: :transaction}
      ]

      TestHelper.get_chain_id_mock()

      Bypass.expect_once(bypass, "POST", "/api/v1/import:batch", fn conn ->
        Conn.resp(
          conn,
          200,
          Jason.encode!(%{"status" => "ok"})
        )
      end)

      assert :ok = MultichainSearchDbExportRetry.run(export_data, nil)
    end

    test "returns {:retry, failed_data} on error where failed_data is only chunks that failed to export", %{
      bypass: _bypass
    } do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        addresses_chunk_size: 1
      )

      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
        Application.put_env(:explorer, :http_adapter, HTTPoison)
      end)

      address_1 = insert(:address)
      address_2 = insert(:address)
      address_3 = insert(:address)
      address_3_hash_string = to_string(address_3) |> String.downcase()
      block = insert(:block)
      block_hash_string = to_string(block.hash)
      block_number = to_string(block.number)
      transaction = insert(:transaction) |> with_block(block)
      transaction_hash_string = to_string(transaction.hash)

      export_data = [
        %{hash: address_1.hash.bytes, hash_type: :address},
        %{hash: address_2.hash.bytes, hash_type: :address},
        %{hash: address_3.hash.bytes, hash_type: :address},
        %{hash: block.hash.bytes, hash_type: :block},
        %{hash: transaction.hash.bytes, hash_type: :transaction}
      ]

      TestHelper.get_chain_id_mock()

      for _ <- 0..2 do
        Explorer.Mox.HTTPoison
        |> expect(:post, fn "http://localhost:1234/api/v1/import:batch",
                            body,
                            [{"Content-Type", "application/json"}],
                            _options ->
          case Jason.decode(body) do
            {:ok, %{"block_ranges" => [%{"max_block_number" => _, "min_block_number" => _}]}} ->
              {:ok, %HTTPoison.Response{status_code: 500, body: Jason.encode!(%{"code" => 0, "message" => "Error"})}}

            _ ->
              {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"status" => "ok"})}}
          end
        end)
      end

      log =
        capture_log(fn ->
          assert {:retry,
                  [
                    %{
                      addresses: [
                        %{
                          hash: ^address_3_hash_string,
                          token_type: "UNSPECIFIED",
                          is_contract: false,
                          token_name: nil,
                          contract_name: nil,
                          ens_name: nil,
                          is_token: false,
                          is_verified_contract: false
                        }
                      ],
                      block_ranges: [%{max_block_number: ^block_number, min_block_number: ^block_number}],
                      hashes: [
                        %{hash: ^block_hash_string, hash_type: "BLOCK"},
                        %{
                          hash: ^transaction_hash_string,
                          hash_type: "TRANSACTION"
                        }
                      ]
                    }
                  ]} = MultichainSearchDbExportRetry.run(export_data, nil)
        end)

      assert log =~ "Batch export retry to the Multichain Search DB failed"

      Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
    end
  end
end
