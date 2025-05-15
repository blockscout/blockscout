defmodule Explorer.MicroserviceInterfaces.MultichainSearchTest do
  use ExUnit.Case
  use Explorer.DataCase
  import Mox

  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.MultichainSearchDbExportRetryQueue
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.{Repo, TestHelper}
  alias Plug.Conn

  setup :verify_on_exit!

  @error_msg "Error while sending request to Multichain Search DB Service"

  describe "batch_import/2" do
    setup do
      Supervisor.terminate_child(Explorer.Supervisor, ChainId.child_id())
      Supervisor.restart_child(Explorer.Supervisor, ChainId.child_id())

      :ok
    end

    test "returns {:ok, :service_disabled} when the service is disabled" do
      params = %{
        addresses: [],
        blocks: [],
        transactions: []
      }

      assert MultichainSearch.batch_import(params) == {:ok, :service_disabled}
    end

    test "processes chunks and returns {:ok, result} when the service is enabled" do
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

      TestHelper.get_chain_id_mock()

      Bypass.expect_once(bypass, "POST", "/api/v1/import:batch", fn conn ->
        Conn.resp(
          conn,
          200,
          Jason.encode!(%{"status" => "ok"})
        )
      end)

      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 0

      block_1 = insert(:block)
      block_2 = insert(:block)

      transaction_1 = insert(:transaction)
      transaction_2 = insert(:transaction)

      address_1 = insert(:address)
      address_2 = insert(:address)

      params = %{
        addresses: [address_1, address_2],
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2]
      }

      assert {:ok, {:chunks_processed, _}} = MultichainSearch.batch_import(params)
      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 0
    end

    test "returns {:error, reason} when an error occurs during processing and 'multichain_search_db_export_retry_queue' table is populated" do
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

      TestHelper.get_chain_id_mock()

      Bypass.expect_once(bypass, "POST", "/api/v1/import:batch", fn conn ->
        Conn.resp(
          conn,
          500,
          Jason.encode!(%{"code" => 0, "message" => "Error"})
        )
      end)

      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 0

      address_1 = insert(:address)
      address_2 = insert(:address)
      block_1 = insert(:block)
      block_2 = insert(:block)
      transaction_1 = insert(:transaction) |> with_block(block_1)
      transaction_2 = insert(:transaction) |> with_block(block_2)

      params = %{
        addresses: [address_1, address_2],
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2]
      }

      assert {:error, @error_msg} = MultichainSearch.batch_import(params)

      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 6
      records = Repo.all(MultichainSearchDbExportRetryQueue)

      assert Enum.all?(records, fn record ->
               (record.hash == address_1.hash.bytes && record.hash_type == :address) ||
                 (record.hash == address_2.hash.bytes && record.hash_type == :address) ||
                 (record.hash == block_1.hash.bytes && record.hash_type == :block) ||
                 (record.hash == block_2.hash.bytes && record.hash_type == :block) ||
                 (record.hash == transaction_1.hash.bytes && record.hash_type == :transaction) ||
                 (record.hash == transaction_2.hash.bytes && record.hash_type == :transaction)
             end)
    end

    test "returns {:error, reason} when at least one chunk is failed" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        addresses_chunk_size: 7000
      )

      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
        Application.put_env(:explorer, :http_adapter, HTTPoison)
      end)

      TestHelper.get_chain_id_mock()

      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 0

      block_1 = insert(:block)
      block_2 = insert(:block)

      transaction_1 = insert(:transaction)
      transaction_2 = insert(:transaction)

      # 7002 addresses (7000 in the first chunk and 2 in the second)
      addresses =
        for _ <- 0..7001 do
          insert(:address)
        end

      Explorer.Mox.HTTPoison
      |> expect(:post, fn "http://localhost:1234/api/v1/import:batch", _expected_body, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"status" => "ok"})}}
      end)

      Explorer.Mox.HTTPoison
      |> expect(:post, fn "http://localhost:1234/api/v1/import:batch",
                          _expected_body,
                          [{"Content-Type", "application/json"}],
                          _options ->
        {:ok, %HTTPoison.Response{status_code: 500, body: Jason.encode!(%{"code" => 0, "message" => "Error"})}}
      end)

      params = %{
        addresses: addresses,
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2]
      }

      assert {:error, @error_msg} = MultichainSearch.batch_import(params)
      # 7000 addresses + 2 blocks + 2 transactions
      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 7004
    end

    test "returns {:error, reason} when an error occurs in all chunks during processing and 'multichain_search_db_export_retry_queue' table is populated with all the input data" do
      bypass = Bypass.open()

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        addresses_chunk_size: 2
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
        Bypass.down(bypass)
      end)

      TestHelper.get_chain_id_mock()

      Bypass.expect(bypass, "POST", "/api/v1/import:batch", fn conn ->
        Conn.resp(
          conn,
          500,
          Jason.encode!(%{"code" => 0, "message" => "Error"})
        )
      end)

      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 0

      addresses = 10 |> insert_list(:address)

      params = %{
        addresses: addresses,
        blocks: [],
        transactions: []
      }

      assert {:error, @error_msg} = MultichainSearch.batch_import(params)

      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 10
    end

    test "returns {:error, reason} when an error occurs in all chunks (and number of chunks more than @max_concurrency) during processing and 'multichain_search_db_export_retry_queue' table is populated with all the input data" do
      bypass = Bypass.open()

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        addresses_chunk_size: 2
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
        Bypass.down(bypass)
      end)

      TestHelper.get_chain_id_mock()

      Bypass.expect(bypass, "POST", "/api/v1/import:batch", fn conn ->
        Conn.resp(
          conn,
          500,
          Jason.encode!(%{"code" => 0, "message" => "Error"})
        )
      end)

      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 0

      addresses = 15 |> insert_list(:address)

      params = %{
        addresses: addresses,
        blocks: [],
        transactions: []
      }

      assert {:error, @error_msg} = MultichainSearch.batch_import(params)

      assert Repo.aggregate(MultichainSearchDbExportRetryQueue, :count, :hash) == 15
    end
  end

  describe "extract_batch_import_params_into_chunks/1" do
    setup do
      TestHelper.get_chain_id_mock()
      Application.put_env(:explorer, MultichainSearch, api_key: "12345", addresses_chunk_size: 7000)
      Supervisor.terminate_child(Explorer.Supervisor, ChainId.child_id())
      Supervisor.restart_child(Explorer.Supervisor, ChainId.child_id())

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, api_key: nil, addresses_chunk_size: 7000)
      end)

      :ok
    end

    test "returns empty chunks when no data is provided" do
      # filling chain_id cache
      ChainId.get_id()

      assert MultichainSearch.extract_batch_import_params_into_chunks(%{
               addresses: [],
               blocks: [],
               transactions: []
             }) == [%{api_key: "12345", addresses: [], block_ranges: [], chain_id: "1", hashes: []}]
    end

    test "returns chunks with transactions and blocks when no addresses provided" do
      block_1 = insert(:block)
      block_2 = insert(:block)
      transaction_1 = insert(:transaction)
      transaction_2 = insert(:transaction)

      params = %{
        addresses: [],
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2]
      }

      chunks = MultichainSearch.extract_batch_import_params_into_chunks(params)

      assert Enum.count(chunks) == 1

      chunk = List.first(chunks)

      assert chunk[:api_key] == "12345"
      assert chunk[:chain_id] == "1"
      assert length(chunk[:addresses]) == 0

      assert chunk[:block_ranges] == [
               %{
                 max_block_number: to_string(max(block_1.number, block_2.number)),
                 min_block_number: to_string(min(block_1.number, block_2.number))
               }
             ]

      assert chunk[:hashes] == [
               %{
                 hash: "0x" <> Base.encode16(block_1.hash.bytes, case: :lower),
                 hash_type: "BLOCK"
               },
               %{
                 hash: "0x" <> Base.encode16(block_2.hash.bytes, case: :lower),
                 hash_type: "BLOCK"
               },
               %{
                 hash: "0x" <> Base.encode16(transaction_1.hash.bytes, case: :lower),
                 hash_type: "TRANSACTION"
               },
               %{
                 hash: "0x" <> Base.encode16(transaction_2.hash.bytes, case: :lower),
                 hash_type: "TRANSACTION"
               }
             ]
    end

    test "returns chunks with the correct structure when all types of data is provided" do
      address_1 = insert(:address)
      address_2 = insert(:address)
      block_1 = insert(:block)
      block_2 = insert(:block)
      transaction_1 = insert(:transaction)
      transaction_2 = insert(:transaction)

      params = %{
        addresses: [address_1, address_2],
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2]
      }

      chunks = MultichainSearch.extract_batch_import_params_into_chunks(params)

      assert Enum.count(chunks) == 1

      chunk = List.first(chunks)

      assert chunk[:api_key] == "12345"
      assert chunk[:chain_id] == "1"

      assert Enum.all?(chunk[:addresses], fn item ->
               item.hash == "0x" <> Base.encode16(address_1.hash.bytes, case: :lower) ||
                 item.hash == "0x" <> Base.encode16(address_2.hash.bytes, case: :lower)
             end)

      assert chunk[:block_ranges] == [
               %{
                 max_block_number: to_string(max(block_1.number, block_2.number)),
                 min_block_number: to_string(min(block_1.number, block_2.number))
               }
             ]

      assert chunk[:hashes] == [
               %{
                 hash: "0x" <> Base.encode16(block_1.hash.bytes, case: :lower),
                 hash_type: "BLOCK"
               },
               %{
                 hash: "0x" <> Base.encode16(block_2.hash.bytes, case: :lower),
                 hash_type: "BLOCK"
               },
               %{
                 hash: "0x" <> Base.encode16(transaction_1.hash.bytes, case: :lower),
                 hash_type: "TRANSACTION"
               },
               %{
                 hash: "0x" <> Base.encode16(transaction_2.hash.bytes, case: :lower),
                 hash_type: "TRANSACTION"
               }
             ]
    end

    test "returns multiple chunks with the correct structure when all types of data is provided" do
      addresses =
        for _ <- 0..7001 do
          insert(:address)
        end

      block_1 = insert(:block)
      block_2 = insert(:block)
      transaction_1 = insert(:transaction)
      transaction_2 = insert(:transaction)

      params = %{
        addresses: addresses,
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2]
      }

      chunks = MultichainSearch.extract_batch_import_params_into_chunks(params)

      assert Enum.count(chunks) == 2

      first_chunk = List.first(chunks)
      second_chunk = List.last(chunks)

      assert first_chunk[:api_key] == "12345"
      assert first_chunk[:chain_id] == "1"

      assert Enum.count(first_chunk[:addresses]) == 7000
      assert Enum.count(second_chunk[:addresses]) == 2

      random_index_in_first_chunk = Enum.random(0..6999)

      assert Enum.any?(first_chunk[:addresses], fn item ->
               item.hash ==
                 "0x" <> Base.encode16(Enum.at(addresses, random_index_in_first_chunk).hash.bytes, case: :lower)
             end)

      assert first_chunk[:block_ranges] == [
               %{
                 max_block_number: to_string(max(block_1.number, block_2.number)),
                 min_block_number: to_string(min(block_1.number, block_2.number))
               }
             ]

      assert first_chunk[:hashes] == [
               %{
                 hash: "0x" <> Base.encode16(block_1.hash.bytes, case: :lower),
                 hash_type: "BLOCK"
               },
               %{
                 hash: "0x" <> Base.encode16(block_2.hash.bytes, case: :lower),
                 hash_type: "BLOCK"
               },
               %{
                 hash: "0x" <> Base.encode16(transaction_1.hash.bytes, case: :lower),
                 hash_type: "TRANSACTION"
               },
               %{
                 hash: "0x" <> Base.encode16(transaction_2.hash.bytes, case: :lower),
                 hash_type: "TRANSACTION"
               }
             ]

      assert second_chunk[:api_key] == "12345"
      assert second_chunk[:chain_id] == "1"

      assert second_chunk[:block_ranges] == []
      assert second_chunk[:hashes] == []

      assert Enum.all?(second_chunk[:addresses], fn item ->
               item.hash == "0x" <> Base.encode16(Enum.at(addresses, -2).hash.bytes, case: :lower) ||
                 item.hash == "0x" <> Base.encode16(List.last(addresses).hash.bytes, case: :lower)
             end)
    end

    test "returns chunks with the correct structure when only addresses are provided" do
      address_1 = insert(:address)
      address_2 = insert(:address)

      params = %{
        addresses: [address_1, address_2],
        blocks: [],
        transactions: []
      }

      chunks = MultichainSearch.extract_batch_import_params_into_chunks(params)

      assert Enum.count(chunks) == 1

      chunk = List.first(chunks)

      assert chunk[:api_key] == "12345"
      assert chunk[:chain_id] == "1"

      assert Enum.all?(chunk[:addresses], fn item ->
               item.hash == "0x" <> Base.encode16(address_1.hash.bytes, case: :lower) ||
                 item.hash == "0x" <> Base.encode16(address_2.hash.bytes, case: :lower)
             end)

      assert chunk[:block_ranges] == []
      assert chunk[:hashes] == []
    end

    test "returns chunks with the correct structure of addresses" do
      address_1 = insert(:address, ens_domain_name: "te.eth")
      address_2 = insert(:address, contract_code: "0x1234")
      address_3 = insert(:address, contract_code: "0x1234", verified: true)
      insert(:smart_contract, address_hash: address_3.hash, contract_code_md5: "123")
      insert(:token, %{contract_address: address_3, name: "Main Token", type: "ERC-721"})

      address_3_with_preloads = address_3 |> Repo.preload([:smart_contract, :token])

      params = %{
        addresses: [address_1, address_2, address_3_with_preloads],
        blocks: [],
        transactions: []
      }

      chunks = MultichainSearch.extract_batch_import_params_into_chunks(params)

      assert Enum.count(chunks) == 1

      chunk = List.first(chunks)

      assert chunk[:api_key] == "12345"
      assert chunk[:chain_id] == "1"

      assert chunk[:addresses] == [
               %{
                 hash: "0x" <> Base.encode16(address_1.hash.bytes, case: :lower),
                 is_contract: false,
                 is_verified_contract: false,
                 contract_name: nil,
                 token_name: nil,
                 token_type: "UNSPECIFIED",
                 is_token: false,
                 ens_name: "te.eth"
               },
               %{
                 hash: "0x" <> Base.encode16(address_2.hash.bytes, case: :lower),
                 is_contract: true,
                 is_verified_contract: false,
                 contract_name: nil,
                 token_name: nil,
                 token_type: "UNSPECIFIED",
                 is_token: false,
                 ens_name: nil
               },
               %{
                 hash: "0x" <> Base.encode16(address_3.hash.bytes, case: :lower),
                 is_contract: true,
                 is_verified_contract: true,
                 contract_name: "SimpleStorage",
                 token_name: "Main Token",
                 token_type: "ERC-721",
                 is_token: true,
                 ens_name: nil
               }
             ]

      assert chunk[:block_ranges] == []
      assert chunk[:hashes] == []
    end
  end
end
