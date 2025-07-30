defmodule Explorer.MicroserviceInterfaces.MultichainSearchTest do
  use ExUnit.Case
  use Explorer.DataCase
  import Mox

  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.MultichainSearchDb.MainExportQueue
  alias Explorer.Chain.Wei
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.{Repo, TestHelper}
  alias Plug.Conn

  setup :verify_on_exit!

  describe "batch_import/2" do
    setup do
      Supervisor.terminate_child(Explorer.Supervisor, ChainId.child_id())
      Supervisor.restart_child(Explorer.Supervisor, ChainId.child_id())

      on_exit(fn ->
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      end)

      :ok
    end

    test "returns {:ok, :service_disabled} when the service is disabled" do
      params = %{
        addresses: [],
        blocks: [],
        transactions: [],
        address_current_token_balances: []
      }

      assert MultichainSearch.batch_import(params) == {:ok, :service_disabled}
    end

    test "processes chunks and returns {:ok, result} when the service is enabled" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

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

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 0

      block_1 = insert(:block)
      block_2 = insert(:block)

      transaction_1 = insert(:transaction)
      transaction_2 = insert(:transaction)

      address_1 = insert(:address)
      address_2 = insert(:address)

      params = %{
        addresses: [address_1, address_2],
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2],
        address_current_token_balances: []
      }

      assert {:ok, {:chunks_processed, _}} = MultichainSearch.batch_import(params)
      assert Repo.aggregate(MainExportQueue, :count, :hash) == 0
    end

    test "returns {:error, data_to_retry} when an error occurs during processing and 'multichain_search_db_main_export_queue' table is populated" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

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

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 0

      address_1 = insert(:address)
      address_2 = insert(:address)
      block_1 = insert(:block)
      block_2 = insert(:block)
      transaction_1 = insert(:transaction) |> with_block(block_1)
      transaction_2 = insert(:transaction) |> with_block(block_2)

      params = %{
        addresses: [address_1, address_2],
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2],
        address_current_token_balances: []
      }

      assert {:error,
              %{
                addresses: [
                  address_export_data(address_2),
                  address_export_data(address_1)
                ],
                block_ranges: [
                  %{max_block_number: to_string(block_2.number), min_block_number: to_string(block_1.number)}
                ],
                hashes: [
                  block_export_data(block_1),
                  block_export_data(block_2),
                  transaction_export_data(transaction_1),
                  transaction_export_data(transaction_2)
                ],
                address_coin_balances: [],
                address_token_balances: []
              }} == MultichainSearch.batch_import(params)

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 6
      records = Repo.all(MainExportQueue)

      assert Enum.all?(records, fn record ->
               (record.hash == address_1.hash.bytes && record.hash_type == :address) ||
                 (record.hash == address_2.hash.bytes && record.hash_type == :address) ||
                 (record.hash == block_1.hash.bytes && record.hash_type == :block) ||
                 (record.hash == block_2.hash.bytes && record.hash_type == :block) ||
                 (record.hash == transaction_1.hash.bytes && record.hash_type == :transaction) ||
                 (record.hash == transaction_2.hash.bytes && record.hash_type == :transaction)
             end)
    end

    test "returns {:error, data_to_retry} when at least one chunk is failed" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        addresses_chunk_size: 7000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
      end)

      TestHelper.get_chain_id_mock()

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 0

      block_1 = insert(:block)
      block_2 = insert(:block)

      transaction_1 = insert(:transaction)
      transaction_2 = insert(:transaction)

      # 7002 addresses (7000 in the first chunk and 2 in the second)
      addresses =
        for _ <- 0..7001 do
          insert(:address)
        end

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "http://localhost:1234/api/v1/import:batch"}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(%{"status" => "ok"})
           }}
        end
      )

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "http://localhost:1234/api/v1/import:batch", headers: [{"Content-Type", "application/json"}]},
                    _opts ->
          {:ok,
           %Tesla.Env{
             status: 500,
             body: Jason.encode!(%{"code" => 0, "message" => "Error"})
           }}
        end
      )

      params = %{
        addresses: addresses,
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2],
        address_current_token_balances: []
      }

      assert {:error, results} = MultichainSearch.batch_import(params)
      assert Enum.count(results.addresses) == 7000
      assert Enum.count(results.block_ranges) == 1
      assert Enum.count(results.hashes) == 4
      # 7000 addresses + 2 blocks + 2 transactions
      assert Repo.aggregate(MainExportQueue, :count, :hash) == 7004
    end

    test "returns {:error, data_to_retry} when an error occurs in all chunks during processing and 'multichain_search_db_main_export_queue' table is populated with all the input data" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

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

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 0

      addresses = 10 |> insert_list(:address)

      params = %{
        addresses: addresses,
        blocks: [],
        transactions: [],
        address_current_token_balances: []
      }

      assert {:error, results} = MultichainSearch.batch_import(params)
      assert Enum.count(results.addresses) == 10
      assert Enum.count(results.block_ranges) == 0
      assert Enum.count(results.hashes) == 0

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 10
    end

    test "returns {:error, data_to_retry} when an error occurs in all chunks (and number of chunks more than @max_concurrency) during processing and 'multichain_search_db_main_export_queue' table is populated with all the input data" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

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

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 0

      addresses = 15 |> insert_list(:address)

      params = %{
        addresses: addresses,
        blocks: [],
        transactions: [],
        address_current_token_balances: []
      }

      assert {:error, results} = MultichainSearch.batch_import(params)
      assert Enum.count(results.addresses) == 15
      assert Enum.count(results.block_ranges) == 0
      assert Enum.count(results.hashes) == 0

      assert Repo.aggregate(MainExportQueue, :count, :hash) == 15
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
               transactions: [],
               address_current_token_balances: []
             }) == [
               %{
                 api_key: "12345",
                 addresses: [],
                 block_ranges: [],
                 chain_id: "1",
                 hashes: [],
                 address_coin_balances: [],
                 address_token_balances: []
               }
             ]
    end

    test "returns chunks with transactions and blocks when no addresses provided" do
      block_1 = insert(:block)
      block_2 = insert(:block)
      transaction_1 = insert(:transaction)
      transaction_2 = insert(:transaction)

      params = %{
        addresses: [],
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2],
        address_current_token_balances: []
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
      address_1 = insert(:address, fetched_coin_balance: Decimal.new(100))
      address_2 = insert(:address, fetched_coin_balance: Decimal.new(200))
      block_1 = insert(:block)
      block_2 = insert(:block)
      transaction_1 = insert(:transaction)
      transaction_2 = insert(:transaction)

      token = insert(:token, contract_address: address_1, type: "ERC-20", name: "Test Token")

      current_token_balance =
        insert(:address_current_token_balance,
          address: address_1,
          token_type: "ERC-20",
          token_id: nil,
          token_contract_address_hash: token.contract_address_hash,
          value: 30_000
        )

      params = %{
        addresses: [address_1, address_2],
        blocks: [block_1, block_2],
        transactions: [transaction_1, transaction_2],
        address_current_token_balances: [current_token_balance]
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
                 hash: to_string(block_1.hash),
                 hash_type: "BLOCK"
               },
               %{
                 hash: to_string(block_2.hash),
                 hash_type: "BLOCK"
               },
               %{
                 hash: to_string(transaction_1.hash),
                 hash_type: "TRANSACTION"
               },
               %{
                 hash: to_string(transaction_2.hash),
                 hash_type: "TRANSACTION"
               }
             ]

      assert chunk[:address_coin_balances] == [
               %{value: %Wei{value: Decimal.new("200")}, address_hash: to_string(address_2.hash)},
               %{value: %Wei{value: Decimal.new("100")}, address_hash: to_string(address_1.hash)}
             ]

      assert chunk[:address_token_balances] == [
               %{
                 value: Decimal.new("30000"),
                 address_hash: to_string(address_1.hash),
                 token_id: nil,
                 token_address_hash: to_string(token.contract_address_hash)
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
        transactions: [transaction_1, transaction_2],
        address_current_token_balances: []
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
               item.hash == "0x" <> Base.encode16(Enum.at(addresses, 0).hash.bytes, case: :lower) ||
                 item.hash == "0x" <> Base.encode16(Enum.at(addresses, 1).hash.bytes, case: :lower)
             end)
    end

    test "returns chunks with the correct structure when only addresses are provided" do
      address_1 = insert(:address)
      address_2 = insert(:address)

      params = %{
        addresses: [address_1, address_2],
        blocks: [],
        transactions: [],
        address_current_token_balances: []
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
        transactions: [],
        address_current_token_balances: []
      }

      chunks = MultichainSearch.extract_batch_import_params_into_chunks(params)

      assert Enum.count(chunks) == 1

      chunk = List.first(chunks)

      assert chunk[:api_key] == "12345"
      assert chunk[:chain_id] == "1"

      assert chunk[:addresses] == [
               %{
                 hash: "0x" <> Base.encode16(address_3.hash.bytes, case: :lower),
                 is_contract: true,
                 is_verified_contract: true,
                 contract_name: "SimpleStorage",
                 token_name: "Main Token",
                 token_type: "ERC-721",
                 is_token: true,
                 ens_name: nil
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
                 hash: "0x" <> Base.encode16(address_1.hash.bytes, case: :lower),
                 is_contract: false,
                 is_verified_contract: false,
                 contract_name: nil,
                 token_name: nil,
                 token_type: "UNSPECIFIED",
                 is_token: false,
                 ens_name: "te.eth"
               }
             ]

      assert chunk[:block_ranges] == []
      assert chunk[:hashes] == []
    end
  end

  defp transaction_export_data(transaction) do
    %{
      hash: "0x" <> Base.encode16(transaction.hash.bytes, case: :lower),
      hash_type: "TRANSACTION"
    }
  end

  defp block_export_data(block) do
    %{
      hash: "0x" <> Base.encode16(block.hash.bytes, case: :lower),
      hash_type: "BLOCK"
    }
  end

  defp address_export_data(address) do
    %{
      hash: "0x" <> Base.encode16(address.hash.bytes, case: :lower),
      token_type: "UNSPECIFIED",
      is_contract: false,
      token_name: nil,
      contract_name: nil,
      ens_name: nil,
      is_token: false,
      is_verified_contract: false
    }
  end
end
