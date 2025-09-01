defmodule Explorer.MicroserviceInterfaces.MultichainSearchTest do
  use ExUnit.Case
  use Explorer.DataCase
  import Mox

  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.MultichainSearchDb.{MainExportQueue, TokenInfoExportQueue}
  alias Explorer.Chain.{Token, Wei}
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.{Repo, TestHelper}
  alias Plug.Conn

  setup :verify_on_exit!

  describe "batch_import/1" do
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
                  address_export_data(address_1),
                  address_export_data(address_2)
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

  describe "batch_export_token_info/1" do
    setup do
      Supervisor.terminate_child(Explorer.Supervisor, ChainId.child_id())
      Supervisor.restart_child(Explorer.Supervisor, ChainId.child_id())

      on_exit(fn ->
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      end)

      :ok
    end

    test "returns {:ok, :service_disabled} when the service is disabled" do
      items_from_db_queue = [insert(:multichain_search_db_export_token_info_queue)]
      assert MultichainSearch.batch_export_token_info(items_from_db_queue) == {:ok, :service_disabled}
    end

    test "processes chunks and returns {:ok, {:chunks_processed, _}} when the service is enabled" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
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

      token_info_item_1 = insert(:multichain_search_db_export_token_info_queue)
      token_info_item_2 = insert(:multichain_search_db_export_token_info_queue)
      items_from_db_queue = [token_info_item_1, token_info_item_2]

      items_from_db_queue
      |> Enum.each(fn item ->
        item
        |> TokenInfoExportQueue.delete_query()
        |> Repo.delete_all()
      end)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0
      assert {:ok, {:chunks_processed, _}} = MultichainSearch.batch_export_token_info(items_from_db_queue)
      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0
    end

    test "returns {:error, data_to_retry} when an error occurs during processing and 'multichain_search_db_export_token_info_queue' table is populated" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
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

      token_info_item_1 = insert(:multichain_search_db_export_token_info_queue)
      token_info_item_2 = insert(:multichain_search_db_export_token_info_queue)
      items_from_db_queue = [token_info_item_1, token_info_item_2]

      items_from_db_queue
      |> Enum.each(fn item ->
        item
        |> TokenInfoExportQueue.delete_query()
        |> Repo.delete_all()
      end)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0

      assert {:error,
              %{
                tokens: [
                  MultichainSearch.token_info_queue_item_to_http_item(token_info_item_1),
                  MultichainSearch.token_info_queue_item_to_http_item(token_info_item_2)
                ]
              }} == MultichainSearch.batch_export_token_info(items_from_db_queue)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 2
      records = Repo.all(TokenInfoExportQueue)

      assert Enum.all?(records, fn record ->
               (record.address_hash == token_info_item_1.address_hash && record.data_type == token_info_item_1.data_type) ||
                 (record.address_hash == token_info_item_2.address_hash &&
                    record.data_type == token_info_item_2.data_type)
             end)
    end

    test "returns {:error, data_to_retry} when an error occurs during processing and retries_number is increased" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
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

      token_info_item_1 = insert(:multichain_search_db_export_token_info_queue)
      token_info_item_2 = insert(:multichain_search_db_export_token_info_queue)
      items_from_db_queue = [token_info_item_1, token_info_item_2]

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 2
      assert is_nil(token_info_item_1.retries_number)
      assert is_nil(token_info_item_2.retries_number)

      assert {:error,
              %{
                tokens: [
                  MultichainSearch.token_info_queue_item_to_http_item(token_info_item_1),
                  MultichainSearch.token_info_queue_item_to_http_item(token_info_item_2)
                ]
              }} == MultichainSearch.batch_export_token_info(items_from_db_queue)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 2
      records = Repo.all(TokenInfoExportQueue)

      assert Enum.all?(records, fn record ->
               (record.address_hash == token_info_item_1.address_hash && record.data_type == token_info_item_1.data_type &&
                  record.retries_number == 1) ||
                 (record.address_hash == token_info_item_2.address_hash &&
                    record.data_type == token_info_item_2.data_type && record.retries_number == 1)
             end)
    end

    test "returns {:error, data_to_retry} when at least one chunk is failed" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
      end)

      TestHelper.get_chain_id_mock()

      # 1002 addresses (1000 in the first chunk and 2 in the second)
      items_from_db_queue =
        for _ <- 0..1001 do
          insert(:multichain_search_db_export_token_info_queue)
        end

      items_from_db_queue
      |> Enum.each(fn item ->
        item
        |> TokenInfoExportQueue.delete_query()
        |> Repo.delete_all()
      end)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0

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

      assert {:error, results} = MultichainSearch.batch_export_token_info(items_from_db_queue)
      assert Enum.count(results.tokens) == 1000
      assert Repo.aggregate(TokenInfoExportQueue, :count) == 1000
    end

    test "returns {:error, data_to_retry} when an error occurs in all chunks during processing and 'multichain_search_db_export_token_info_queue' table is populated with all the input data" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        token_info_chunk_size: 2
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
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

      items_from_db_queue = 10 |> insert_list(:multichain_search_db_export_token_info_queue)

      items_from_db_queue
      |> Enum.each(fn item ->
        item
        |> TokenInfoExportQueue.delete_query()
        |> Repo.delete_all()
      end)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0
      assert {:error, results} = MultichainSearch.batch_export_token_info(items_from_db_queue)
      assert Enum.count(results.tokens) == 10
      assert Repo.aggregate(TokenInfoExportQueue, :count) == 10
    end

    test "returns {:error, data_to_retry} when an error occurs in all chunks (and number of chunks more than @max_concurrency) during processing and 'multichain_search_db_export_token_info_queue' table is populated" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        token_info_chunk_size: 2
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
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

      items_from_db_queue = 15 |> insert_list(:multichain_search_db_export_token_info_queue)

      items_from_db_queue
      |> Enum.each(fn item ->
        item
        |> TokenInfoExportQueue.delete_query()
        |> Repo.delete_all()
      end)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0
      assert {:error, results} = MultichainSearch.batch_export_token_info(items_from_db_queue)
      assert Enum.count(results.tokens) == 15
      assert Repo.aggregate(TokenInfoExportQueue, :count) == 15
    end
  end

  describe "token_info_queue_item_to_http_item/1" do
    test "returns correct map to send to multichain service" do
      address_hash_string = "0x000102030405060708090a0b0c0d0e0f10111213"
      address_hash_binary = Base.decode16!("000102030405060708090a0b0c0d0e0f10111213", case: :mixed)

      assert MultichainSearch.token_info_queue_item_to_http_item(%{
               address_hash: address_hash_binary,
               data_type: :metadata,
               data: %{token_type: "ERC-20", name: "TestToken", symbol: "TEST", decimals: 18, total_supply: "1000"}
             }) == %{
               address_hash: address_hash_string,
               metadata: %{token_type: "ERC-20", name: "TestToken", symbol: "TEST", decimals: 18, total_supply: "1000"}
             }

      assert MultichainSearch.token_info_queue_item_to_http_item(%{
               address_hash: address_hash_binary,
               data_type: :total_supply,
               data: %{total_supply: "1000"}
             }) == %{
               address_hash: address_hash_string,
               metadata: %{total_supply: "1000"}
             }

      assert MultichainSearch.token_info_queue_item_to_http_item(%{
               address_hash: address_hash_binary,
               data_type: :counters,
               data: %{holders_count: "123", transfers_count: "456"}
             }) == %{
               address_hash: address_hash_string,
               counters: %{holders_count: "123", transfers_count: "456"}
             }

      assert MultichainSearch.token_info_queue_item_to_http_item(%{
               address_hash: address_hash_binary,
               data_type: :market_data,
               data: %{fiat_value: "123.456", circulating_market_cap: "1000.0001"}
             }) == %{
               address_hash: address_hash_string,
               price_data: %{fiat_value: "123.456", circulating_market_cap: "1000.0001"}
             }
    end
  end

  describe "token_info_http_item_to_queue_item/1" do
    test "returns correct map to add to queue" do
      address_hash_string = "0x000102030405060708090a0b0c0d0e0f10111213"
      address_hash_binary = Base.decode16!("000102030405060708090a0b0c0d0e0f10111213", case: :mixed)

      assert MultichainSearch.token_info_http_item_to_queue_item(%{
               address_hash: address_hash_string,
               metadata: %{token_type: "ERC-20", name: "TestToken", symbol: "TEST", decimals: 18, total_supply: "1000"}
             }) == %{
               address_hash: address_hash_binary,
               data_type: :metadata,
               data: %{token_type: "ERC-20", name: "TestToken", symbol: "TEST", decimals: 18, total_supply: "1000"}
             }

      assert MultichainSearch.token_info_http_item_to_queue_item(%{
               address_hash: address_hash_string,
               metadata: %{token_type: "ERC-20"}
             }) == %{
               address_hash: address_hash_binary,
               data_type: :metadata,
               data: %{token_type: "ERC-20"}
             }

      assert MultichainSearch.token_info_http_item_to_queue_item(%{
               address_hash: address_hash_string,
               metadata: %{total_supply: "1000"}
             }) == %{
               address_hash: address_hash_binary,
               data_type: :total_supply,
               data: %{total_supply: "1000"}
             }

      assert MultichainSearch.token_info_http_item_to_queue_item(%{
               address_hash: address_hash_string,
               counters: %{holders_count: "123", transfers_count: "456"}
             }) == %{
               address_hash: address_hash_binary,
               data_type: :counters,
               data: %{holders_count: "123", transfers_count: "456"}
             }

      assert MultichainSearch.token_info_http_item_to_queue_item(%{
               address_hash: address_hash_string,
               price_data: %{fiat_value: "123.456", circulating_market_cap: "1000.0001"}
             }) == %{
               address_hash: address_hash_binary,
               data_type: :market_data,
               data: %{fiat_value: "123.456", circulating_market_cap: "1000.0001"}
             }
    end
  end

  describe "prepare_token_metadata_for_queue/2" do
    test "returns an empty map when the service is disabled" do
      assert MultichainSearch.prepare_token_metadata_for_queue(%Token{type: "ERC-20"}, %{name: "TestToken"}) == %{}
    end

    test "returns correct map to add to queue" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
      end)

      assert MultichainSearch.prepare_token_metadata_for_queue(
               %Token{
                 type: "ERC-20",
                 icon_url: "http://localhost:1235/test.png",
                 name: "TestToken",
                 symbol: "TST"
               },
               %{
                 name: "TestToken2",
                 symbol: "TST2",
                 decimals: 18,
                 total_supply: 123
               }
             ) == %{
               token_type: "ERC-20",
               icon_url: "http://localhost:1235/test.png",
               name: "TestToken2",
               symbol: "TST2",
               decimals: 18,
               total_supply: "123"
             }

      assert MultichainSearch.prepare_token_metadata_for_queue(
               %Token{
                 type: "ERC-20",
                 name: "TestToken",
                 symbol: "TST"
               },
               %{
                 name: "TestToken2",
                 symbol: "TST2",
                 decimals: 18
               }
             ) == %{
               token_type: "ERC-20",
               name: "TestToken2",
               symbol: "TST2",
               decimals: 18
             }

      assert MultichainSearch.prepare_token_metadata_for_queue(
               %Token{
                 type: "ERC-1155",
                 name: "TestToken",
                 symbol: "TST"
               },
               %{
                 name: "TestToken2",
                 symbol: "TST2"
               }
             ) == %{
               token_type: "ERC-1155",
               name: "TestToken2",
               symbol: "TST2"
             }

      assert MultichainSearch.prepare_token_metadata_for_queue(
               %Token{
                 type: "ERC-1155",
                 name: "TestToken",
                 symbol: "TST"
               },
               %{
                 name: "TestToken2"
               }
             ) == %{
               token_type: "ERC-1155",
               name: "TestToken2"
             }

      assert MultichainSearch.prepare_token_metadata_for_queue(
               %Token{
                 type: "ERC-1155",
                 name: "TestToken",
                 symbol: "TST"
               },
               %{}
             ) == %{
               token_type: "ERC-1155"
             }

      assert MultichainSearch.prepare_token_metadata_for_queue(
               %Token{type: "ERC-1155"},
               %{}
             ) == %{
               token_type: "ERC-1155"
             }
    end
  end

  describe "prepare_token_total_supply_for_queue/1" do
    test "returns nil when the service is disabled" do
      assert is_nil(MultichainSearch.prepare_token_total_supply_for_queue(1000))
    end

    test "returns correct map to add to queue" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
      end)

      assert MultichainSearch.prepare_token_total_supply_for_queue(1000) == %{total_supply: "1000"}
    end
  end

  describe "prepare_token_market_data_for_queue/1" do
    test "returns an empty map when the service is disabled" do
      assert MultichainSearch.prepare_token_market_data_for_queue(%{
               fiat_value: Decimal.new("100.5"),
               circulating_market_cap: Decimal.new("2000.28")
             }) == %{}
    end

    test "returns correct map to add to queue" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
      end)

      assert MultichainSearch.prepare_token_market_data_for_queue(%{
               fiat_value: Decimal.new("100.5"),
               circulating_market_cap: Decimal.new("2000.28")
             }) == %{fiat_value: "100.5", circulating_market_cap: "2000.28"}

      assert MultichainSearch.prepare_token_market_data_for_queue(%{
               fiat_value: Decimal.new("100.5"),
               circulating_market_cap: Decimal.new("2000.28"),
               name: "TestToken"
             }) == %{fiat_value: "100.5", circulating_market_cap: "2000.28"}

      assert MultichainSearch.prepare_token_market_data_for_queue(%{fiat_value: Decimal.new("100.5")}) == %{
               fiat_value: "100.5"
             }

      assert MultichainSearch.prepare_token_market_data_for_queue(%{circulating_market_cap: Decimal.new("2000.28")}) ==
               %{circulating_market_cap: "2000.28"}

      assert MultichainSearch.prepare_token_market_data_for_queue(%{name: "TestToken"}) == %{}
      assert MultichainSearch.prepare_token_market_data_for_queue(%{}) == %{}
    end
  end

  describe "prepare_token_counters_for_queue/2" do
    test "returns an empty map when the service is disabled" do
      assert MultichainSearch.prepare_token_counters_for_queue(456, 123) == %{}
    end

    test "returns correct map to add to queue" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
      end)

      assert MultichainSearch.prepare_token_counters_for_queue(456, 123) == %{
               transfers_count: "456",
               holders_count: "123"
             }

      assert MultichainSearch.prepare_token_counters_for_queue(0, 0) == %{transfers_count: "0", holders_count: "0"}
    end
  end

  describe "send_token_info_to_queue/2" do
    test "does nothing and returns :ignore when the service is disabled" do
      address_hash_binary = Base.decode16!("000102030405060708090a0b0c0d0e0f10111213", case: :mixed)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0

      assert MultichainSearch.send_token_info_to_queue(%{address_hash_binary => %{total_supply: "123"}}, :total_supply) ==
               :ignore

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0
    end

    test "adds an item to db queue and returns :ok" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
      end)

      address_hash_binary = Base.decode16!("000102030405060708090a0b0c0d0e0f10111213", case: :mixed)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0

      assert MultichainSearch.send_token_info_to_queue(%{address_hash_binary => %{total_supply: "123"}}, :total_supply) ==
               :ok

      [record] = Repo.all(TokenInfoExportQueue)

      assert record.address_hash == address_hash_binary && record.data_type == :total_supply &&
               record.data == %{"total_supply" => "123"}
    end

    test "adds all items to db queue" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        token_info_chunk_size: 2
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
      end)

      address1_hash_binary = Base.decode16!("000102030405060708090a0b0c0d0e0f10111213", case: :mixed)
      address2_hash_binary = Base.decode16!("000102030405060708090a0b0c0d0e0f10111214", case: :mixed)
      address3_hash_binary = Base.decode16!("000102030405060708090a0b0c0d0e0f10111215", case: :mixed)
      address4_hash_binary = Base.decode16!("000102030405060708090a0b0c0d0e0f10111216", case: :mixed)

      entries = %{
        address1_hash_binary => %{total_supply: "123"},
        address2_hash_binary => %{total_supply: "124"},
        address3_hash_binary => %{total_supply: "125"},
        address4_hash_binary => %{total_supply: "126"}
      }

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0
      assert MultichainSearch.send_token_info_to_queue(entries, :total_supply) == :ok

      records = Repo.all(TokenInfoExportQueue)

      assert Enum.all?(records, fn record ->
               (record.address_hash == address1_hash_binary && record.data_type == :total_supply &&
                  record.data == %{"total_supply" => "123"}) ||
                 (record.address_hash == address2_hash_binary && record.data_type == :total_supply &&
                    record.data == %{"total_supply" => "124"}) ||
                 (record.address_hash == address3_hash_binary && record.data_type == :total_supply &&
                    record.data == %{"total_supply" => "125"}) ||
                 (record.address_hash == address4_hash_binary && record.data_type == :total_supply &&
                    record.data == %{"total_supply" => "126"})
             end)
    end

    test "replaces an existing item in the db queue and updates `updated_at` field" do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        token_info_chunk_size: 1000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, token_info_chunk_size: 1000)
      end)

      address_hash_binary = Base.decode16!("000102030405060708090a0b0c0d0e0f10111213", case: :mixed)

      assert Repo.aggregate(TokenInfoExportQueue, :count) == 0

      assert MultichainSearch.send_token_info_to_queue(%{address_hash_binary => %{total_supply: "123"}}, :total_supply) ==
               :ok

      [record] = Repo.all(TokenInfoExportQueue)

      assert record.address_hash == address_hash_binary && record.data_type == :total_supply &&
               record.data == %{"total_supply" => "123"}

      assert MultichainSearch.send_token_info_to_queue(%{address_hash_binary => %{total_supply: "124"}}, :total_supply) ==
               :ok

      [record_new] = Repo.all(TokenInfoExportQueue)

      assert record_new.address_hash == address_hash_binary && record_new.data_type == :total_supply &&
               record_new.data == %{"total_supply" => "124"} &&
               DateTime.compare(record_new.updated_at, record.updated_at) == :gt
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
               %{value: %Wei{value: Decimal.new("100")}, address_hash: to_string(address_1.hash)},
               %{value: %Wei{value: Decimal.new("200")}, address_hash: to_string(address_2.hash)}
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
               item.hash == "0x" <> Base.encode16(Enum.at(addresses, 7000).hash.bytes, case: :lower) ||
                 item.hash == "0x" <> Base.encode16(Enum.at(addresses, 7001).hash.bytes, case: :lower)
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
