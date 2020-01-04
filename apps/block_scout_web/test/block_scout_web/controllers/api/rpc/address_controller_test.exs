defmodule BlockScoutWeb.API.RPC.AddressControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  import Mox

  alias BlockScoutWeb.API.RPC.AddressController
  alias Explorer.Chain
  alias Explorer.Chain.{Events.Subscriber, Transaction, Wei}
  alias Explorer.Counters.{AddressesCounter, AverageBlockTime}
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Explorer.Repo

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    mocked_json_rpc_named_arguments = [
      transport: EthereumJSONRPC.Mox,
      transport_options: []
    ]

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    start_supervised!(AverageBlockTime)
    start_supervised!({CoinBalanceOnDemand, [mocked_json_rpc_named_arguments, [name: CoinBalanceOnDemand]]})
    start_supervised!(AddressesCounter)

    Application.put_env(:explorer, AverageBlockTime, enabled: true)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false)
    end)

    :ok
  end

  describe "listaccounts" do
    setup do
      Subscriber.to(:addresses, :on_demand)
      Subscriber.to(:address_coin_balances, :on_demand)

      %{params: %{"module" => "account", "action" => "listaccounts"}}
    end

    test "with no addresses", %{params: params, conn: conn} do
      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      schema = listaccounts_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["message"] == "OK"
      assert response["status"] == "1"
      assert response["result"] == []
    end

    test "with existing addresses", %{params: params, conn: conn} do
      first_address = insert(:address, fetched_coin_balance: 10, inserted_at: Timex.shift(Timex.now(), minutes: -10))
      second_address = insert(:address, fetched_coin_balance: 100, inserted_at: Timex.shift(Timex.now(), minutes: -5))
      first_address_hash = to_string(first_address.hash)
      second_address_hash = to_string(second_address.hash)

      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      schema = listaccounts_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert [
               %{
                 "address" => ^first_address_hash,
                 "balance" => "10"
               },
               %{
                 "address" => ^second_address_hash,
                 "balance" => "100"
               }
             ] = response["result"]
    end

    test "with a stale balance", %{conn: conn, params: params} do
      now = Timex.now()

      mining_address =
        insert(:address,
          fetched_coin_balance: 0,
          fetched_coin_balance_block_number: 102,
          inserted_at: Timex.shift(now, minutes: -10)
        )

      mining_address_hash = to_string(mining_address.hash)
      # we space these very far apart so that we know it will consider the 0th block stale (it calculates how far
      # back we'd need to go to get 24 hours in the past)
      Enum.each(0..100, fn i ->
        insert(:block, number: i, timestamp: Timex.shift(now, hours: -(102 - i) * 25), miner: mining_address)
      end)

      insert(:block, number: 101, timestamp: Timex.shift(now, hours: -25), miner: mining_address)
      AverageBlockTime.refresh()

      address =
        insert(:address,
          fetched_coin_balance: 100,
          fetched_coin_balance_block_number: 100,
          inserted_at: Timex.shift(now, minutes: -5)
        )

      address_hash = to_string(address.hash)

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn [
                                                     %{
                                                       id: id,
                                                       method: "eth_getBalance",
                                                       params: [^address_hash, "0x65"]
                                                     }
                                                   ],
                                                   _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x02"}]}
      end)

      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      schema = listaccounts_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["message"] == "OK"
      assert response["status"] == "1"

      assert [
               %{
                 "address" => ^mining_address_hash,
                 "balance" => "0",
                 "stale" => false
               },
               %{
                 "address" => ^address_hash,
                 "balance" => "100",
                 "stale" => true
               }
             ] = response["result"]

      {:ok, expected_wei} = Wei.cast(2)

      assert_receive({:chain_event, :addresses, :on_demand, [received_address]})

      assert received_address.hash == address.hash
      assert received_address.fetched_coin_balance == expected_wei
      assert received_address.fetched_coin_balance_block_number == 101
    end
  end

  describe "balance" do
    test "with missing address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "balance"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["message"] =~ "'address' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["message"] =~ "Invalid address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["result"] == "0"
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a valid address", %{conn: conn} do
      address = insert(:address, fetched_coin_balance: 100)

      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => "#{address.hash}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["result"] == "#{address.fetched_coin_balance.value}"
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with multiple valid addresses", %{conn: conn} do
      addresses =
        for _ <- 1..2 do
          insert(:address, fetched_coin_balance: Enum.random(1..1_000))
        end

      address_param =
        addresses
        |> Enum.map(&"#{&1.hash}")
        |> Enum.join(",")

      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => address_param
      }

      expected_result =
        Enum.map(addresses, fn address ->
          %{"account" => "#{address.hash}", "balance" => "#{address.fetched_coin_balance.value}", "stale" => false}
        end)

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "supports GET and POST requests", %{conn: conn} do
      address = insert(:address, fetched_coin_balance: 100)

      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => "#{address.hash}"
      }

      assert get_response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert post_response =
               conn
               |> post("/api", params)
               |> json_response(200)

      assert get_response == post_response
    end
  end

  describe "balancemulti" do
    test "with an invalid and a valid address hash", %{conn: conn} do
      address1 = "invalidhash"
      address2 = "0x9bf49d5875030175f3d5d4a67631a87ab4df526b"

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address1},#{address2}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["message"] =~ "Invalid address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with multiple addresses that don't exist", %{conn: conn} do
      address1 = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      address2 = "0x9bf49d5875030175f3d5d4a67631a87ab4df526b"

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address1},#{address2}"
      }

      expected_result = [
        %{"account" => address1, "balance" => "0", "stale" => false},
        %{"account" => address2, "balance" => "0", "stale" => false}
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with multiple valid addresses", %{conn: conn} do
      addresses =
        for _ <- 1..4 do
          insert(:address, fetched_coin_balance: Enum.random(1..1_000))
        end

      address_param =
        addresses
        |> Enum.map(&"#{&1.hash}")
        |> Enum.join(",")

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => address_param
      }

      expected_result =
        Enum.map(addresses, fn address ->
          %{"account" => "#{address.hash}", "balance" => "#{address.fetched_coin_balance.value}", "stale" => false}
        end)

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an address that exists and one that doesn't", %{conn: conn} do
      address1 = insert(:address, fetched_coin_balance: 100)
      address2_hash = "0x9bf49d5875030175f3d5d4a67631a87ab4df526b"

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address1.hash},#{address2_hash}"
      }

      expected_result = [
        %{"account" => address2_hash, "balance" => "0", "stale" => false},
        %{"account" => "#{address1.hash}", "balance" => "#{address1.fetched_coin_balance.value}", "stale" => false}
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "up to a maximum of 20 addresses in a single request", %{conn: conn} do
      addresses = insert_list(25, :address, fetched_coin_balance: 0)

      address_param =
        addresses
        |> Enum.map(&"#{&1.hash}")
        |> Enum.join(",")

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => address_param
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 20
      assert response["status"] == "1"
      assert response["message"] == "OK"

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with a single address", %{conn: conn} do
      address = insert(:address, fetched_coin_balance: 100)

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address.hash}"
      }

      expected_result = [
        %{"account" => "#{address.hash}", "balance" => "#{address.fetched_coin_balance.value}", "stale" => false}
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      schema = balance_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "supports GET and POST requests", %{conn: conn} do
      addresses =
        for _ <- 1..4 do
          insert(:address, fetched_coin_balance: Enum.random(1..1_000))
        end

      address_param =
        addresses
        |> Enum.map(&"#{&1.hash}")
        |> Enum.join(",")

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => address_param
      }

      assert get_response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert post_response =
               conn
               |> post("/api", params)
               |> json_response(200)

      assert get_response == post_response
    end
  end

  describe "txlist" do
    test "with missing address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "txlist"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "'address' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "0"
      assert response["message"] == "No transactions found"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with a valid address", %{conn: conn} do
      address = insert(:address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(from_address: address)
        |> with_block(status: :ok)

      # ^ 'status: :ok' means `isError` in response should be '0'

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}"
      }

      expected_result = [
        %{
          "blockNumber" => "#{transaction.block_number}",
          "timeStamp" => "#{DateTime.to_unix(block.timestamp)}",
          "hash" => "#{transaction.hash}",
          "nonce" => "#{transaction.nonce}",
          "blockHash" => "#{block.hash}",
          "transactionIndex" => "#{transaction.index}",
          "from" => "#{transaction.from_address_hash}",
          "to" => "#{transaction.to_address_hash}",
          "value" => "#{transaction.value.value}",
          "gas" => "#{transaction.gas}",
          "gasPrice" => "#{transaction.gas_price.value}",
          "isError" => "0",
          "txreceipt_status" => "1",
          "input" => "#{transaction.input}",
          "contractAddress" => "#{transaction.created_contract_address_hash}",
          "cumulativeGasUsed" => "#{transaction.cumulative_gas_used}",
          "gasUsed" => "#{transaction.gas_used}",
          "confirmations" => "0"
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "includes correct confirmations value", %{conn: conn} do
      insert(:block)
      address = insert(:address)

      transaction =
        %Transaction{hash: hash} =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      insert(:block)

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}"
      }

      block_height = Chain.block_height()
      expected_confirmations = block_height - transaction.block_number

      assert %{"result" => [returned_transaction]} =
               response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert returned_transaction["confirmations"] == "#{expected_confirmations}"
      assert returned_transaction["hash"] == "#{hash}"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "returns '1' for 'isError' with failed transaction", %{conn: conn} do
      address = insert(:address)

      %Transaction{hash: hash} =
        :transaction
        |> insert(from_address: address)
        |> with_block(status: :error)

      # ^ 'status: :error' means `isError` in response should be '1'

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}"
      }

      assert %{"result" => [returned_transaction]} =
               response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert returned_transaction["isError"] == "1"
      assert returned_transaction["txreceipt_status"] == "0"
      assert returned_transaction["hash"] == "#{hash}"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with address with multiple transactions", %{conn: conn} do
      address1 = insert(:address)
      address2 = insert(:address)

      transactions =
        3
        |> insert_list(:transaction, from_address: address1)
        |> with_block()

      :transaction
      |> insert(from_address: address2)
      |> with_block()

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address1.hash}"
      }

      expected_transaction_hashes = Enum.map(transactions, &"#{&1.hash}")

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 3

      for returned_transaction <- response["result"] do
        assert returned_transaction["hash"] in expected_transaction_hashes
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "orders transactions by block, in ascending order", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)
      address = insert(:address)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(third_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "sort" => "asc"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      block_numbers_order =
        Enum.map(response["result"], fn transaction ->
          String.to_integer(transaction["blockNumber"])
        end)

      assert block_numbers_order == Enum.sort(block_numbers_order, &(&1 <= &2))
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "orders transactions by block, in descending order", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)
      address = insert(:address)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(third_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "sort" => "desc"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      block_numbers_order =
        Enum.map(response["result"], fn transaction ->
          String.to_integer(transaction["blockNumber"])
        end)

      assert block_numbers_order == Enum.sort(block_numbers_order, &(&1 >= &2))
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "ignores invalid sort option, defaults to ascending", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)
      address = insert(:address)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(third_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "sort" => "invalidsortoption"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      block_numbers_order =
        Enum.map(response["result"], fn transaction ->
          String.to_integer(transaction["blockNumber"])
        end)

      assert block_numbers_order == Enum.sort(block_numbers_order, &(&1 >= &2))
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with valid pagination params", %{conn: conn} do
      # To get paginated results on this endpoint Etherscan's docs say:
      #
      # "(To get paginated results use page=<page number> and offset=<max
      # records to return>)"

      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)
      address = insert(:address)

      _second_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(second_block)

      first_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(third_block)

      _third_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(first_block)

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        # page number
        "page" => "1",
        # page size
        "offset" => "2"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      page1_hashes = Enum.map(response["result"], & &1["hash"])

      assert length(response["result"]) == 2

      for transaction <- first_block_transactions do
        assert "#{transaction.hash}" in page1_hashes
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "ignores pagination params when invalid", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)
      address = insert(:address)

      _second_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(second_block)

      _third_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(third_block)

      _first_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(first_block)

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        # page number
        "page" => "invalidpage",
        # page size
        "offset" => "invalidoffset"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 6
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "ignores offset param if offset is less than 1", %{conn: conn} do
      address = insert(:address)

      6
      |> insert_list(:transaction, from_address: address)
      |> with_block()

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        # page number
        "page" => "1",
        # page size
        "offset" => "0"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 6
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "ignores offset param if offset is over 10,000", %{conn: conn} do
      address = insert(:address)

      6
      |> insert_list(:transaction, from_address: address)
      |> with_block()

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        # page number
        "page" => "1",
        # page size
        "offset" => "10_500"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 6
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with page number with no results", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)
      address = insert(:address)

      _second_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(second_block)

      _third_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(third_block)

      _first_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(first_block)

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        # page number
        "page" => "5",
        # page size
        "offset" => "2"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "0"
      assert response["message"] == "No transactions found"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with startblock and endblock params", %{conn: conn} do
      blocks = [_, second_block, third_block, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "startblock" => "#{second_block.number}",
        "endblock" => "#{third_block.number}"
      }

      expected_block_numbers = [
        "#{second_block.number}",
        "#{third_block.number}"
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 4

      for transaction <- response["result"] do
        assert transaction["blockNumber"] in expected_block_numbers
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with startblock but without endblock", %{conn: conn} do
      blocks = [_, _, third_block, fourth_block] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "startblock" => "#{third_block.number}"
      }

      expected_block_numbers = [
        "#{third_block.number}",
        "#{fourth_block.number}"
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 4

      for transaction <- response["result"] do
        assert transaction["blockNumber"] in expected_block_numbers
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with endblock but without startblock", %{conn: conn} do
      blocks = [first_block, second_block, _, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "endblock" => "#{second_block.number}"
      }

      expected_block_numbers = [
        "#{first_block.number}",
        "#{second_block.number}"
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 4

      for transaction <- response["result"] do
        assert transaction["blockNumber"] in expected_block_numbers
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "ignores invalid startblock and endblock", %{conn: conn} do
      blocks = [_, _, _, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "startblock" => "invalidstart",
        "endblock" => "invalidend"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 8
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with starttimestamp and endtimestamp params", %{conn: conn} do
      now = Timex.now()
      timestamp1 = Timex.shift(now, hours: -6)
      timestamp2 = Timex.shift(now, hours: -3)
      timestamp3 = Timex.shift(now, hours: -1)
      blocks1 = insert_list(2, :block, timestamp: timestamp1)
      blocks2 = [third_block, fourth_block] = insert_list(2, :block, timestamp: timestamp2)
      blocks3 = insert_list(2, :block, timestamp: timestamp3)
      address = insert(:address)

      for block <- Enum.concat([blocks1, blocks2, blocks3]) do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      start_timestamp = now |> Timex.shift(hours: -4) |> Timex.to_unix()
      end_timestamp = now |> Timex.shift(hours: -2) |> Timex.to_unix()

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "starttimestamp" => "#{start_timestamp}",
        "endtimestamp" => "#{end_timestamp}"
      }

      expected_block_numbers = [
        "#{third_block.number}",
        "#{fourth_block.number}"
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 4

      for transaction <- response["result"] do
        assert transaction["blockNumber"] in expected_block_numbers
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with starttimestamp but without endtimestamp", %{conn: conn} do
      now = Timex.now()
      timestamp1 = Timex.shift(now, hours: -6)
      timestamp2 = Timex.shift(now, hours: -3)
      timestamp3 = Timex.shift(now, hours: -1)
      blocks1 = insert_list(2, :block, timestamp: timestamp1)
      blocks2 = [third_block, fourth_block] = insert_list(2, :block, timestamp: timestamp2)
      blocks3 = [fifth_block, sixth_block] = insert_list(2, :block, timestamp: timestamp3)
      address = insert(:address)

      for block <- Enum.concat([blocks1, blocks2, blocks3]) do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      start_timestamp = now |> Timex.shift(hours: -4) |> Timex.to_unix()

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "starttimestamp" => "#{start_timestamp}"
      }

      expected_block_numbers = [
        "#{third_block.number}",
        "#{fourth_block.number}",
        "#{fifth_block.number}",
        "#{sixth_block.number}"
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 8

      for transaction <- response["result"] do
        assert transaction["blockNumber"] in expected_block_numbers
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with endtimestamp but without starttimestamp", %{conn: conn} do
      now = Timex.now()
      timestamp1 = Timex.shift(now, hours: -6)
      timestamp2 = Timex.shift(now, hours: -3)
      timestamp3 = Timex.shift(now, hours: -1)
      blocks1 = [first_block, second_block] = insert_list(2, :block, timestamp: timestamp1)
      blocks2 = insert_list(2, :block, timestamp: timestamp2)
      blocks3 = insert_list(2, :block, timestamp: timestamp3)
      address = insert(:address)

      for block <- Enum.concat([blocks1, blocks2, blocks3]) do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      end_timestamp = now |> Timex.shift(hours: -5) |> Timex.to_unix()

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "endtimestamp" => "#{end_timestamp}"
      }

      expected_block_numbers = [
        "#{first_block.number}",
        "#{second_block.number}"
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 4

      for transaction <- response["result"] do
        assert transaction["blockNumber"] in expected_block_numbers
      end

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with filterby=to option", %{conn: conn} do
      block = insert(:block)
      address = insert(:address)

      insert(:transaction, from_address: address)
      |> with_block(block)

      insert(:transaction, to_address: address)
      |> with_block(block)

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "filterby" => "to"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 1
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "with filterby=from option", %{conn: conn} do
      block = insert(:block)
      address = insert(:address)

      insert(:transaction, from_address: address)
      |> with_block(block)

      insert(:transaction, from_address: address)
      |> with_block(block)

      insert(:transaction, to_address: address)
      |> with_block(block)

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        "filterby" => "from"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 2
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlist_schema(), response)
    end

    test "supports GET and POST requests", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}"
      }

      assert get_response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert post_response =
               conn
               |> post("/api", params)
               |> json_response(200)

      assert get_response == post_response
    end
  end

  describe "txlistinternal" do
    test "with missing txhash and address", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "txlistinternal"
      }

      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      assert response["message"] =~ "txhash or address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end
  end

  describe "txlistinternal with txhash" do
    test "with an invalid txhash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "txhash" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid txhash format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end

    test "with a txhash that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "txhash" => "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "0"
      assert response["message"] == "No internal transactions found"
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end

    test "response includes all the expected fields", %{conn: conn} do
      address = insert(:address)
      contract_address = insert(:contract_address)

      block = insert(:block)

      transaction =
        :transaction
        |> insert(from_address: address, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block(block)

      internal_transaction =
        :internal_transaction_create
        |> insert(
          transaction: transaction,
          index: 0,
          from_address: address,
          block_hash: transaction.block_hash,
          block_index: 0
        )
        |> with_contract_creation(contract_address)

      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "txhash" => "#{transaction.hash}"
      }

      expected_result = [
        %{
          "blockNumber" => "#{transaction.block_number}",
          "timeStamp" => "#{DateTime.to_unix(block.timestamp)}",
          "from" => "#{internal_transaction.from_address_hash}",
          "to" => "#{internal_transaction.to_address_hash}",
          "value" => "#{internal_transaction.value.value}",
          "contractAddress" => "#{contract_address.hash}",
          "input" => "",
          "type" => "#{internal_transaction.type}",
          "gas" => "#{internal_transaction.gas}",
          "gasUsed" => "#{internal_transaction.gas_used}",
          "index" => "#{internal_transaction.index}",
          "transactionHash" => "#{transaction.hash}",
          "isError" => "0",
          "errCode" => "#{internal_transaction.error}"
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end

    test "isError is true if internal transaction has an error", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      internal_transaction_details = [
        transaction: transaction,
        index: 0,
        type: :reward,
        error: "some error",
        block_hash: transaction.block_hash,
        block_index: 0
      ]

      insert(:internal_transaction_create, internal_transaction_details)

      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "txhash" => "#{transaction.hash}"
      }

      assert %{"result" => [found_internal_transaction]} =
               response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert found_internal_transaction["isError"] == "1"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end

    test "with transaction with multiple internal transactions", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      for index <- 0..2 do
        insert(:internal_transaction_create,
          transaction: transaction,
          index: index,
          block_hash: transaction.block_hash,
          block_index: index
        )
      end

      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "txhash" => "#{transaction.hash}"
      }

      assert %{"result" => found_internal_transactions} =
               response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(found_internal_transactions) == 3
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end
  end

  describe "txlistinternal with address" do
    test "with an invalid address", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end

    test "with a address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "0"
      assert response["message"] == "No internal transactions found"
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end

    test "response includes all the expected fields", %{conn: conn} do
      address = insert(:address)
      contract_address = insert(:contract_address)

      block = insert(:block)

      transaction =
        :transaction
        |> insert(from_address: address, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block(block)

      internal_transaction =
        :internal_transaction_create
        |> insert(
          transaction: transaction,
          index: 0,
          from_address: address,
          block_number: block.number,
          block_hash: transaction.block_hash,
          block_index: 0
        )
        |> with_contract_creation(contract_address)

      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "address" => "#{address.hash}"
      }

      expected_result = [
        %{
          "blockNumber" => "#{transaction.block_number}",
          "timeStamp" => "#{DateTime.to_unix(block.timestamp)}",
          "from" => "#{internal_transaction.from_address_hash}",
          "to" => "#{internal_transaction.to_address_hash}",
          "value" => "#{internal_transaction.value.value}",
          "contractAddress" => "#{contract_address.hash}",
          "input" => "",
          "type" => "#{internal_transaction.type}",
          "gas" => "#{internal_transaction.gas}",
          "gasUsed" => "#{internal_transaction.gas_used}",
          "isError" => "0",
          "index" => "#{internal_transaction.index}",
          "transactionHash" => "#{transaction.hash}",
          "errCode" => "#{internal_transaction.error}"
        }
      ]

      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end

    test "isError is true if internal transaction has an error", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      internal_transaction_details = [
        from_address: address,
        transaction: transaction,
        index: 0,
        type: :reward,
        error: "some error",
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0
      ]

      insert(:internal_transaction_create, internal_transaction_details)

      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "address" => "#{address.hash}"
      }

      assert %{"result" => [found_internal_transaction]} =
               response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert found_internal_transaction["isError"] == "1"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end

    test "with transaction with multiple internal transactions", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      for index <- 0..2 do
        internal_transaction_details = %{
          from_address: address,
          transaction: transaction,
          index: index,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: index
        }

        insert(:internal_transaction_create, internal_transaction_details)
      end

      params = %{
        "module" => "account",
        "action" => "txlistinternal",
        "address" => "#{address.hash}"
      }

      assert %{"result" => found_internal_transactions} =
               response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(found_internal_transactions) == 3
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(txlistinternal_schema(), response)
    end
  end

  describe "tokentx" do
    test "with missing address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokentx"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokentx_schema(), response)
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokentx",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokentx_schema(), response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokentx",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "0"
      assert response["message"] == "No token transfers found"
      assert :ok = ExJsonSchema.Validator.validate(tokentx_schema(), response)
    end

    test "has correct value for ERC-721", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_address = insert(:contract_address)
      insert(:token, %{contract_address: token_address, type: "ERC-721"})

      token_transfer =
        insert(:token_transfer, %{
          token_contract_address: token_address,
          token_id: 666,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        })

      {:ok, _} = Chain.token_from_address_hash(token_transfer.token_contract_address_hash)

      params = %{
        "module" => "account",
        "action" => "tokentx",
        "address" => to_string(token_transfer.from_address.hash)
      }

      assert response =
               %{"result" => [result]} =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert result["tokenID"] == to_string(token_transfer.token_id)
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokentx_schema(), response)
    end

    test "returns all the required fields", %{conn: conn} do
      transaction =
        %{block: block} =
        :transaction
        |> insert()
        |> with_block()

      token_transfer =
        insert(:token_transfer, block: transaction.block, transaction: transaction, block_number: block.number)

      {:ok, token} = Chain.token_from_address_hash(token_transfer.token_contract_address_hash)

      params = %{
        "module" => "account",
        "action" => "tokentx",
        "address" => to_string(token_transfer.from_address.hash)
      }

      expected_result = [
        %{
          "blockNumber" => to_string(transaction.block_number),
          "timeStamp" => to_string(DateTime.to_unix(block.timestamp)),
          "hash" => to_string(token_transfer.transaction_hash),
          "nonce" => to_string(transaction.nonce),
          "blockHash" => to_string(block.hash),
          "from" => to_string(token_transfer.from_address_hash),
          "contractAddress" => to_string(token_transfer.token_contract_address_hash),
          "to" => to_string(token_transfer.to_address_hash),
          "value" => to_string(token_transfer.amount),
          "tokenName" => token.name,
          "tokenSymbol" => token.symbol,
          "tokenDecimal" => to_string(token.decimals),
          "transactionIndex" => to_string(transaction.index),
          "gas" => to_string(transaction.gas),
          "gasPrice" => to_string(transaction.gas_price.value),
          "gasUsed" => to_string(transaction.gas_used),
          "cumulativeGasUsed" => to_string(transaction.cumulative_gas_used),
          "logIndex" => to_string(token_transfer.log_index),
          "input" => to_string(transaction.input),
          "confirmations" => "0"
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokentx_schema(), response)
    end

    test "with an invalid contract address", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokentx",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
        "contractaddress" => "invalid"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contractaddress format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokentx_schema(), response)
    end

    test "filters results by contract address", %{conn: conn} do
      address = insert(:address)

      contract_address = insert(:contract_address)

      insert(:token, contract_address: contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        from_address: address,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      insert(:token_transfer,
        from_address: address,
        token_contract_address: contract_address,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      params = %{
        "module" => "account",
        "action" => "tokentx",
        "address" => to_string(address.hash),
        "contractaddress" => to_string(contract_address.hash)
      }

      assert response =
               %{"result" => [result]} =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert result["contractAddress"] == to_string(contract_address.hash)
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokentx_schema(), response)
    end
  end

  describe "tokenbalance" do
    test "without required params", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokenbalance"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "missing: address, contractaddress"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokenbalance_schema(), response)
    end

    test "with contractaddress but without address", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokenbalance",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "missing: address"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokenbalance_schema(), response)
    end

    test "with address but without contractaddress", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokenbalance",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "missing: contractaddress"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokenbalance_schema(), response)
    end

    test "with an invalid contractaddress hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokenbalance",
        "contractaddress" => "badhash",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contractaddress format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokenbalance_schema(), response)
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokenbalance",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokenbalance_schema(), response)
    end

    test "with a contractaddress and address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokenbalance",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
        "address" => "0x9bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == "0"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokenbalance_schema(), response)
    end

    test "with contractaddress and address without row in token_balances table", %{conn: conn} do
      token = insert(:token)
      address = insert(:address)

      params = %{
        "module" => "account",
        "action" => "tokenbalance",
        "contractaddress" => to_string(token.contract_address_hash),
        "address" => to_string(address.hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == "0"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokenbalance_schema(), response)
    end

    test "with contractaddress and address with existing balance in token_balances table", %{conn: conn} do
      token_balance = insert(:token_balance)

      params = %{
        "module" => "account",
        "action" => "tokenbalance",
        "contractaddress" => to_string(token_balance.token_contract_address_hash),
        "address" => to_string(token_balance.address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == to_string(token_balance.value)
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokenbalance_schema(), response)
    end
  end

  describe "tokenlist" do
    test "without address param", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokenlist"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokenlist_schema(), response)
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokenlist",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(tokenlist_schema(), response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "tokenlist",
        "address" => "0x9bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "0"
      assert response["message"] == "No tokens found"
      assert :ok = ExJsonSchema.Validator.validate(tokenlist_schema(), response)
    end

    test "with an address without row in token_balances table", %{conn: conn} do
      address = insert(:address)

      params = %{
        "module" => "account",
        "action" => "tokenlist",
        "address" => to_string(address.hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "0"
      assert response["message"] == "No tokens found"
      assert :ok = ExJsonSchema.Validator.validate(tokenlist_schema(), response)
    end

    test "with address with existing balance in token_balances table", %{conn: conn} do
      token_balance = :token_balance |> insert() |> Repo.preload(:token)

      params = %{
        "module" => "account",
        "action" => "tokenlist",
        "address" => to_string(token_balance.address_hash)
      }

      expected_result = [
        %{
          "balance" => to_string(token_balance.value),
          "contractAddress" => to_string(token_balance.token_contract_address_hash),
          "name" => token_balance.token.name,
          "decimals" => to_string(token_balance.token.decimals),
          "symbol" => token_balance.token.symbol,
          "type" => token_balance.token.type
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokenlist_schema(), response)
    end

    test "with address with multiple tokens", %{conn: conn} do
      address = insert(:address)
      other_address = insert(:address)
      insert(:token_balance, address: address)
      insert(:token_balance, address: address)
      insert(:token_balance, address: other_address)

      params = %{
        "module" => "account",
        "action" => "tokenlist",
        "address" => to_string(address.hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 2
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokenlist_schema(), response)
    end
  end

  describe "getminedblocks" do
    test "with missing address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "getminedblocks"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "'address' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(block_schema(), response)
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "getminedblocks",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(block_schema(), response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "getminedblocks",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "0"
      assert response["message"] == "No blocks found"
      assert :ok = ExJsonSchema.Validator.validate(block_schema(), response)
    end

    test "returns all the required fields", %{conn: conn} do
      %{block_range: range} = insert(:emission_reward)

      block = insert(:block, number: Enum.random(Range.new(range.from, range.to)))

      :transaction
      |> insert(gas_price: 1)
      |> with_block(block, gas_used: 1)

      expected_result = [
        %{
          "blockNumber" => to_string(block.number),
          "timeStamp" => to_string(block.timestamp)
        }
      ]

      params = %{
        "module" => "account",
        "action" => "getminedblocks",
        "address" => to_string(block.miner_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(block_schema(), response)
    end

    test "with a block with one transaction", %{conn: conn} do
      %{block_range: range} = insert(:emission_reward)

      block = insert(:block, number: Enum.random(Range.new(range.from, range.to)))

      :transaction
      |> insert(gas_price: 1)
      |> with_block(block, gas_used: 1)

      params = %{
        "module" => "account",
        "action" => "getminedblocks",
        "address" => to_string(block.miner_hash)
      }

      expected_result = [
        %{
          "blockNumber" => to_string(block.number),
          "timeStamp" => to_string(block.timestamp)
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(block_schema(), response)
    end

    test "with pagination options", %{conn: conn} do
      %{block_range: range} = insert(:emission_reward)

      block_numbers = Range.new(range.from, range.to)

      [block_number1, block_number2] = Enum.take(block_numbers, 2)

      address = insert(:address)

      _block1 = insert(:block, number: block_number1, miner: address)
      block2 = insert(:block, number: block_number2, miner: address)

      :transaction
      |> insert(gas_price: 2)
      |> with_block(block2, gas_used: 2)

      params = %{
        "module" => "account",
        "action" => "getminedblocks",
        "address" => to_string(address.hash),
        # page number
        "page" => "1",
        # page size
        "offset" => "1"
      }

      expected_result = [
        %{
          "blockNumber" => to_string(block2.number),
          "timeStamp" => to_string(block2.timestamp)
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(block_schema(), response)
    end
  end

  describe "optional_params/1" do
    test "includes valid optional params in the required format" do
      params = %{
        "startblock" => "100",
        "endblock" => "120",
        "sort" => "asc",
        # page number
        "page" => "1",
        # page size
        "offset" => "2",
        "filterby" => "to",
        "starttimestamp" => "1539186474",
        "endtimestamp" => "1539186474"
      }

      optional_params = AddressController.optional_params(params)

      # 1539186474 equals "2018-10-10 15:47:54Z"
      {:ok, expected_timestamp, _} = DateTime.from_iso8601("2018-10-10 15:47:54Z")

      assert optional_params.page_number == 1
      assert optional_params.page_size == 2
      assert optional_params.order_by_direction == :asc
      assert optional_params.start_block == 100
      assert optional_params.end_block == 120
      assert optional_params.filter_by == "to"
      assert optional_params.start_timestamp == expected_timestamp
      assert optional_params.end_timestamp == expected_timestamp
    end

    test "'sort' values can be 'asc' or 'desc'" do
      params1 = %{"sort" => "asc"}

      optional_params = AddressController.optional_params(params1)

      assert optional_params.order_by_direction == :asc

      params2 = %{"sort" => "desc"}

      optional_params = AddressController.optional_params(params2)

      assert optional_params.order_by_direction == :desc

      params3 = %{"sort" => "invalid"}

      assert AddressController.optional_params(params3) == %{}
    end

    test "'filterby' value can be 'to' or 'from'" do
      params1 = %{"filterby" => "to"}

      optional_params1 = AddressController.optional_params(params1)

      assert optional_params1.filter_by == "to"

      params2 = %{"filterby" => "from"}

      optional_params2 = AddressController.optional_params(params2)

      assert optional_params2.filter_by == "from"

      params3 = %{"filterby" => "invalid"}

      assert AddressController.optional_params(params3) == %{}
    end

    test "only includes optional params when they're given" do
      assert AddressController.optional_params(%{}) == %{}
    end

    test "ignores invalid optional params, keeps valid ones" do
      params1 = %{
        "startblock" => "invalid",
        "endblock" => "invalid",
        "sort" => "invalid",
        "page" => "invalid",
        "offset" => "invalid",
        "starttimestamp" => "invalid",
        "endtimestamp" => "invalid"
      }

      assert AddressController.optional_params(params1) == %{}

      params2 = %{
        "startblock" => "4",
        "endblock" => "10",
        "sort" => "invalid",
        "page" => "invalid",
        "offset" => "invalid",
        "starttimestamp" => "invalid",
        "endtimestamp" => "invalid"
      }

      optional_params = AddressController.optional_params(params2)

      assert optional_params.start_block == 4
      assert optional_params.end_block == 10
    end

    test "ignores 'page' if less than 1" do
      params = %{"page" => "0"}

      assert AddressController.optional_params(params) == %{}
    end

    test "ignores 'offset' if less than 1" do
      params = %{"offset" => "0"}

      assert AddressController.optional_params(params) == %{}
    end

    test "ignores 'offset' if more than 10,000" do
      params = %{"offset" => "10001"}

      assert AddressController.optional_params(params) == %{}
    end
  end

  describe "fetch_required_params/2" do
    test "returns error with missing param" do
      params = %{"address" => "some address"}

      required_params = ~w(address contractaddress)

      result = AddressController.fetch_required_params(params, required_params)

      assert result == {:required_params, {:error, ["contractaddress"]}}
    end

    test "returns ok with all required params" do
      params = %{"address" => "some address", "contractaddress" => "some contract"}

      required_params = ~w(address contractaddress)

      result = AddressController.fetch_required_params(params, required_params)

      assert result == {:required_params, {:ok, params}}
    end
  end

  defp listaccounts_schema do
    resolve_schema(%{
      "type" => "array",
      "items" => %{
        "type" => "object",
        "properties" => %{
          "address" => %{"type" => "string"},
          "balance" => %{"type" => "string"},
          "stale" => %{"type" => "boolean"}
        }
      }
    })
  end

  defp balance_schema do
    resolve_schema(%{
      "type" => ["string", "null", "array"],
      "items" => %{
        "type" => "object",
        "properties" => %{
          "account" => %{"type" => "string"},
          "balance" => %{"type" => "string"},
          "stale" => %{"type" => "boolean"}
        }
      }
    })
  end

  defp txlist_schema do
    resolve_schema(%{
      "type" => ["null", "array"],
      "items" => %{
        "type" => "object",
        "properties" => %{
          "blockNumber" => %{"type" => "string"},
          "timeStamp" => %{"type" => "string"},
          "hash" => %{"type" => "string"},
          "nonce" => %{"type" => "string"},
          "blockHash" => %{"type" => "string"},
          "transactionIndex" => %{"type" => "string"},
          "from" => %{"type" => "string"},
          "to" => %{"type" => "string"},
          "value" => %{"type" => "string"},
          "gas" => %{"type" => "string"},
          "gasPrice" => %{"type" => "string"},
          "isError" => %{"type" => "string"},
          "txreceipt_status" => %{"type" => "string"},
          "input" => %{"type" => "string"},
          "contractAddress" => %{"type" => "string"},
          "cumulativeGasUsed" => %{"type" => "string"},
          "gasUsed" => %{"type" => "string"},
          "confirmations" => %{"type" => "string"}
        }
      }
    })
  end

  defp txlistinternal_schema do
    resolve_schema(%{
      "type" => ["array", "null"],
      "items" => %{
        "type" => "object",
        "properties" => %{
          "blockNumber" => %{"type" => "string"},
          "timeStamp" => %{"type" => "string"},
          "from" => %{"type" => "string"},
          "to" => %{"type" => "string"},
          "value" => %{"type" => "string"},
          "contractAddress" => %{"type" => "string"},
          "transactionHash" => %{"type" => "string"},
          "index" => %{"type" => "string"},
          "input" => %{"type" => "string"},
          "type" => %{"type" => "string"},
          "gas" => %{"type" => "string"},
          "gasUsed" => %{"type" => "string"},
          "isError" => %{"type" => "string"},
          "errCode" => %{"type" => "string"}
        }
      }
    })
  end

  defp tokentx_schema do
    resolve_schema(%{
      "type" => ["array", "null"],
      "items" => %{
        "type" => "object",
        "properties" => %{
          "blockNumber" => %{"type" => "string"},
          "timeStamp" => %{"type" => "string"},
          "hash" => %{"type" => "string"},
          "nonce" => %{"type" => "string"},
          "blockHash" => %{"type" => "string"},
          "from" => %{"type" => "string"},
          "contractAddress" => %{"type" => "string"},
          "to" => %{"type" => "string"},
          "logIndex" => %{"type" => "string"},
          "value" => %{"type" => "string"},
          "tokenName" => %{"type" => "string"},
          "tokenID" => %{"type" => "string"},
          "tokenSymbol" => %{"type" => "string"},
          "tokenDecimal" => %{"type" => "string"},
          "transactionIndex" => %{"type" => "string"},
          "gas" => %{"type" => "string"},
          "gasPrice" => %{"type" => "string"},
          "gasUsed" => %{"type" => "string"},
          "cumulativeGasUsed" => %{"type" => "string"},
          "input" => %{"type" => "string"},
          "confirmations" => %{"type" => "string"}
        }
      }
    })
  end

  defp tokenbalance_schema, do: resolve_schema(%{"type" => ["string", "null"]})

  defp tokenlist_schema do
    resolve_schema(%{
      "type" => ["array", "null"],
      "items" => %{
        "type" => "object",
        "properties" => %{
          "balance" => %{"type" => "string"},
          "contractAddress" => %{"type" => "string"},
          "name" => %{"type" => "string"},
          "decimals" => %{"type" => "string"},
          "symbol" => %{"type" => "string"},
          "type" => %{"type" => "string"}
        }
      }
    })
  end

  defp block_schema do
    resolve_schema(%{
      "type" => ["array", "null"],
      "items" => %{
        "type" => "object",
        "properties" => %{
          "blockNumber" => %{"type" => "string"},
          "timeStamp" => %{"type" => "string"},
          "blockReward" => %{"type" => "string"}
        }
      }
    })
  end

  defp resolve_schema(result) do
    %{
      "type" => "object",
      "properties" => %{
        "message" => %{"type" => "string"},
        "status" => %{"type" => "string"}
      }
    }
    |> put_in(["properties", "result"], result)
    |> ExJsonSchema.Schema.resolve()
  end
end
