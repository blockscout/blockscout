defmodule BlockScoutWeb.API.RPC.EthControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  alias Explorer.Counters.{AddressesCounter, AverageBlockTime}
  alias Explorer.Repo
  alias Indexer.Fetcher.CoinBalanceOnDemand

  setup do
    mocked_json_rpc_named_arguments = [
      transport: EthereumJSONRPC.Mox,
      transport_options: []
    ]

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    start_supervised!(AverageBlockTime)
    start_supervised!({CoinBalanceOnDemand, [mocked_json_rpc_named_arguments, [name: CoinBalanceOnDemand]]})
    start_supervised!(AddressesCounter)

    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

    :ok
  end

  defp params(api_params, params), do: Map.put(api_params, "params", params)

  describe "eth_get_logs" do
    setup do
      %{
        api_params: %{
          "method" => "eth_getLogs",
          "jsonrpc" => "2.0",
          "id" => 0
        }
      }
    end

    test "with an invalid address", %{conn: conn, api_params: api_params} do
      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [%{"address" => "badhash"}]))
               |> json_response(200)

      assert %{"error" => "invalid address"} = response
    end

    test "address with no logs", %{conn: conn, api_params: api_params} do
      insert(:block)
      address = insert(:address)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [%{"address" => to_string(address.hash)}]))
               |> json_response(200)

      assert %{"result" => []} = response
    end

    test "address but no logs and no toBlock provided", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [%{"address" => to_string(address.hash)}]))
               |> json_response(200)

      assert %{"result" => []} = response
    end

    test "with a matching address", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      block = insert(:block, number: 0)

      transaction = insert(:transaction, from_address: address) |> with_block(block)
      insert(:log, block: block, address: address, transaction: transaction, data: "0x010101")

      params = params(api_params, [%{"address" => to_string(address.hash)}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert %{"result" => [%{"data" => "0x010101"}]} = response
    end

    test "with a matching address and matching topic", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      block = insert(:block, number: 0)

      transaction = insert(:transaction, from_address: address) |> with_block(block)
      insert(:log, block: block, address: address, transaction: transaction, data: "0x010101", first_topic: "0x01")

      params = params(api_params, [%{"address" => to_string(address.hash), "topics" => ["0x01"]}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert %{"result" => [%{"data" => "0x010101"}]} = response
    end

    test "with a matching address and multiple topic matches", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      block = insert(:block, number: 0)

      transaction = insert(:transaction, from_address: address) |> with_block(block)
      insert(:log, address: address, block: block, transaction: transaction, data: "0x010101", first_topic: "0x01")
      insert(:log, address: address, block: block, transaction: transaction, data: "0x020202", first_topic: "0x00")

      params = params(api_params, [%{"address" => to_string(address.hash), "topics" => [["0x01", "0x00"]]}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert [%{"data" => "0x010101"}, %{"data" => "0x020202"}] = Enum.sort_by(response["result"], &Map.get(&1, "data"))
    end

    test "paginates logs", %{conn: conn, api_params: api_params} do
      contract_address = insert(:contract_address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(block)

      inserted_records =
        insert_list(2000, :log, block: block, address: contract_address, transaction: transaction, first_topic: "0x01")

      params = params(api_params, [%{"address" => to_string(contract_address), "topics" => [["0x01"]]}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert Enum.count(response["result"]) == 1000

      {last_log_index, ""} = Integer.parse(List.last(response["result"])["logIndex"], 16)

      next_page_params = %{
        "blockNumber" => Integer.to_string(transaction.block_number, 16),
        "transactionIndex" => transaction.index,
        "logIndex" => Integer.to_string(last_log_index, 16)
      }

      new_params =
        params(api_params, [
          %{"paging_options" => next_page_params, "address" => to_string(contract_address), "topics" => [["0x01"]]}
        ])

      assert new_response =
               conn
               |> post("/api/eth-rpc", new_params)
               |> json_response(200)

      assert Enum.count(response["result"]) == 1000

      all_found_logs = response["result"] ++ new_response["result"]

      assert Enum.all?(inserted_records, fn record ->
               Enum.any?(all_found_logs, fn found_log ->
                 {index, ""} = Integer.parse(found_log["logIndex"], 16)

                 record.index == index
               end)
             end)
    end

    test "with a matching address and multiple topic matches in different positions", %{
      conn: conn,
      api_params: api_params
    } do
      address = insert(:address)

      block = insert(:block, number: 0)

      transaction = insert(:transaction, from_address: address) |> with_block(block)

      insert(:log,
        address: address,
        transaction: transaction,
        data: "0x010101",
        first_topic: "0x01",
        second_topic: "0x02",
        block: block
      )

      insert(:log, block: block, address: address, transaction: transaction, data: "0x020202", first_topic: "0x01")

      params = params(api_params, [%{"address" => to_string(address.hash), "topics" => ["0x01", "0x02"]}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert [%{"data" => "0x010101"}] = response["result"]
    end

    test "with a matching address and multiple topic matches in different positions and multiple matches in the second position",
         %{conn: conn, api_params: api_params} do
      address = insert(:address)

      block = insert(:block, number: 0)

      transaction = insert(:transaction, from_address: address) |> with_block(block)

      insert(:log,
        address: address,
        transaction: transaction,
        data: "0x010101",
        first_topic: "0x01",
        second_topic: "0x02",
        block: block
      )

      insert(:log,
        address: address,
        transaction: transaction,
        data: "0x020202",
        first_topic: "0x01",
        second_topic: "0x03",
        block: block
      )

      params = params(api_params, [%{"address" => to_string(address.hash), "topics" => ["0x01", ["0x02", "0x03"]]}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert [%{"data" => "0x010101"}, %{"data" => "0x020202"}] = Enum.sort_by(response["result"], &Map.get(&1, "data"))
    end

    test "with a block range filter",
         %{conn: conn, api_params: api_params} do
      address = insert(:address)

      block1 = insert(:block, number: 0)
      block2 = insert(:block, number: 1)
      block3 = insert(:block, number: 2)
      block4 = insert(:block, number: 3)

      transaction1 = insert(:transaction, from_address: address) |> with_block(block1)
      transaction2 = insert(:transaction, from_address: address) |> with_block(block2)
      transaction3 = insert(:transaction, from_address: address) |> with_block(block3)
      transaction4 = insert(:transaction, from_address: address) |> with_block(block4)

      insert(:log, address: address, transaction: transaction1, data: "0x010101")

      insert(:log, address: address, transaction: transaction2, data: "0x020202")

      insert(:log, address: address, transaction: transaction3, data: "0x030303")

      insert(:log, address: address, transaction: transaction4, data: "0x040404")

      params = params(api_params, [%{"address" => to_string(address.hash), "fromBlock" => 1, "toBlock" => 2}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert [%{"data" => "0x020202"}, %{"data" => "0x030303"}] = Enum.sort_by(response["result"], &Map.get(&1, "data"))
    end

    test "with a block hash filter",
         %{conn: conn, api_params: api_params} do
      address = insert(:address)

      block1 = insert(:block, number: 0)
      block2 = insert(:block, number: 1)
      block3 = insert(:block, number: 2)

      transaction1 = insert(:transaction, from_address: address) |> with_block(block1)
      transaction2 = insert(:transaction, from_address: address) |> with_block(block2)
      transaction3 = insert(:transaction, from_address: address) |> with_block(block3)

      insert(:log, address: address, transaction: transaction1, data: "0x010101")

      insert(:log, address: address, transaction: transaction2, data: "0x020202")

      insert(:log, address: address, transaction: transaction3, data: "0x030303")

      params = params(api_params, [%{"address" => to_string(address.hash), "blockHash" => to_string(block2.hash)}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert [%{"data" => "0x020202"}] = response["result"]
    end

    test "with an earliest block filter",
         %{conn: conn, api_params: api_params} do
      address = insert(:address)

      block1 = insert(:block, number: 0)
      block2 = insert(:block, number: 1)
      block3 = insert(:block, number: 2)

      transaction1 = insert(:transaction, from_address: address) |> with_block(block1)
      transaction2 = insert(:transaction, from_address: address) |> with_block(block2)
      transaction3 = insert(:transaction, from_address: address) |> with_block(block3)

      insert(:log, address: address, transaction: transaction1, data: "0x010101")

      insert(:log, address: address, transaction: transaction2, data: "0x020202")

      insert(:log, address: address, transaction: transaction3, data: "0x030303")

      params =
        params(api_params, [%{"address" => to_string(address.hash), "fromBlock" => "earliest", "toBlock" => "earliest"}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert [%{"data" => "0x010101"}] = response["result"]
    end

    test "with a pending block filter",
         %{conn: conn, api_params: api_params} do
      address = insert(:address)

      block1 = insert(:block, number: 0)
      block2 = insert(:block, number: 1)
      block3 = insert(:block, number: 2)

      transaction1 = insert(:transaction, from_address: address) |> with_block(block1)
      transaction2 = insert(:transaction, from_address: address) |> with_block(block2)
      transaction3 = insert(:transaction, from_address: address) |> with_block(block3)

      insert(:log, block: block1, address: address, transaction: transaction1, data: "0x010101")

      insert(:log, block: block2, address: address, transaction: transaction2, data: "0x020202")

      insert(:log, block: block3, address: address, transaction: transaction3, data: "0x030303")

      changeset = Ecto.Changeset.change(block3, %{consensus: false})

      Repo.update!(changeset)

      params =
        params(api_params, [%{"address" => to_string(address.hash), "fromBlock" => "pending", "toBlock" => "pending"}])

      assert response =
               conn
               |> post("/api/eth-rpc", params)
               |> json_response(200)

      assert [%{"data" => "0x030303"}] = response["result"]
    end
  end

  describe "eth_get_balance" do
    setup do
      %{
        api_params: %{
          "method" => "eth_getBalance",
          "jsonrpc" => "2.0",
          "id" => 0
        }
      }
    end

    test "with an invalid address", %{conn: conn, api_params: api_params} do
      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, ["badHash"]))
               |> json_response(200)

      assert %{"error" => "Query parameter 'address' is invalid"} = response
    end

    test "with a valid address that has no balance", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [to_string(address.hash)]))
               |> json_response(200)

      assert %{"error" => "Balance not found"} = response
    end

    test "with a valid address that has a balance", %{conn: conn, api_params: api_params} do
      block = insert(:block)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [to_string(address.hash)]))
               |> json_response(200)

      assert %{"result" => "0x1"} = response
    end

    test "with a valid address that has no earliest balance", %{conn: conn, api_params: api_params} do
      block = insert(:block, number: 1)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [to_string(address.hash), "earliest"]))
               |> json_response(200)

      assert response["error"] == "Balance not found"
    end

    test "with a valid address that has an earliest balance", %{conn: conn, api_params: api_params} do
      block = insert(:block, number: 0)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [to_string(address.hash), "earliest"]))
               |> json_response(200)

      assert response["result"] == "0x1"
    end

    test "with a valid address and no pending balance", %{conn: conn, api_params: api_params} do
      block = insert(:block, number: 1, consensus: true)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [to_string(address.hash), "pending"]))
               |> json_response(200)

      assert response["error"] == "Balance not found"
    end

    test "with a valid address and a pending balance", %{conn: conn, api_params: api_params} do
      block = insert(:block, number: 1, consensus: false)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [to_string(address.hash), "pending"]))
               |> json_response(200)

      assert response["result"] == "0x1"
    end

    test "with a valid address and a pending balance after a consensus block", %{conn: conn, api_params: api_params} do
      insert(:block, number: 1, consensus: true)
      block = insert(:block, number: 2, consensus: false)
      address = insert(:address)

      insert(:fetched_balance, block_number: block.number, address_hash: address.hash, value: 1)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [to_string(address.hash), "pending"]))
               |> json_response(200)

      assert response["result"] == "0x1"
    end

    test "with a block provided", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      insert(:fetched_balance, block_number: 1, address_hash: address.hash, value: 1)
      insert(:fetched_balance, block_number: 2, address_hash: address.hash, value: 2)
      insert(:fetched_balance, block_number: 3, address_hash: address.hash, value: 3)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [to_string(address.hash), "2"]))
               |> json_response(200)

      assert response["result"] == "0x2"
    end

    test "with a block provided and no balance", %{conn: conn, api_params: api_params} do
      address = insert(:address)

      insert(:fetched_balance, block_number: 3, address_hash: address.hash, value: 3)

      assert response =
               conn
               |> post("/api/eth-rpc", params(api_params, [to_string(address.hash), "2"]))
               |> json_response(200)

      assert response["error"] == "Balance not found"
    end

    test "with a batch of requests", %{conn: conn} do
      address = insert(:address)

      insert(:fetched_balance, block_number: 1, address_hash: address.hash, value: 1)
      insert(:fetched_balance, block_number: 2, address_hash: address.hash, value: 2)
      insert(:fetched_balance, block_number: 3, address_hash: address.hash, value: 3)

      params = [
        %{"id" => 0, "params" => [to_string(address.hash), "1"], "jsonrpc" => "2.0", "method" => "eth_getBalance"},
        %{"id" => 1, "params" => [to_string(address.hash), "2"], "jsonrpc" => "2.0", "method" => "eth_getBalance"},
        %{"id" => 2, "params" => [to_string(address.hash), "3"], "jsonrpc" => "2.0", "method" => "eth_getBalance"}
      ]

      assert response =
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/api/eth-rpc", Jason.encode!(params))
               |> json_response(200)

      assert [
               %{"id" => 0, "result" => "0x1"},
               %{"id" => 1, "result" => "0x2"},
               %{"id" => 2, "result" => "0x3"}
             ] = response
    end
  end
end
