defmodule ExplorerWeb.API.RPC.AddressControllerTest do
  use ExplorerWeb.ConnCase

  alias Explorer.Chain
  alias Explorer.Chain.{Transaction, Wei}

  describe "balance" do
    test "with missing address hash", %{conn: conn} do
      params = %{
        "module" => "account",
        "action" => "balance"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(400)

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
               |> json_response(400)

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

      assert response["result"] == "0"
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a valid address", %{conn: conn} do
      address = insert(:address, fetched_balance: 100)

      params = %{
        "module" => "account",
        "action" => "balance",
        "address" => "#{address.hash}"
      }

      expected_balance =
        address.fetched_balance
        |> Wei.to(:ether)
        |> Decimal.to_string(:normal)

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_balance
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with multiple valid addresses", %{conn: conn} do
      addresses =
        for _ <- 1..2 do
          insert(:address, fetched_balance: Enum.random(1..1_000))
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
          expected_balance =
            address.fetched_balance
            |> Wei.to(:ether)
            |> Decimal.to_string(:normal)

          %{"account" => "#{address.hash}", "balance" => expected_balance}
        end)

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
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
               |> json_response(400)

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
        %{"account" => address1, "balance" => "0"},
        %{"account" => address2, "balance" => "0"}
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with multiple valid addresses", %{conn: conn} do
      addresses =
        for _ <- 1..4 do
          insert(:address, fetched_balance: Enum.random(1..1_000))
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
          expected_balance =
            address.fetched_balance
            |> Wei.to(:ether)
            |> Decimal.to_string(:normal)

          %{"account" => "#{address.hash}", "balance" => expected_balance}
        end)

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with an address that exists and one that doesn't", %{conn: conn} do
      address1 = insert(:address, fetched_balance: 100)
      address2_hash = "0x9bf49d5875030175f3d5d4a67631a87ab4df526b"

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address1.hash},#{address2_hash}"
      }

      expected_balance1 =
        address1.fetched_balance
        |> Wei.to(:ether)
        |> Decimal.to_string(:normal)

      expected_result = [
        %{"account" => address2_hash, "balance" => "0"},
        %{"account" => "#{address1.hash}", "balance" => expected_balance1}
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "up to a maximum of 20 addresses in a single request", %{conn: conn} do
      addresses = insert_list(25, :address, fetched_balance: 0)

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
    end

    test "with a single address", %{conn: conn} do
      address = insert(:address, fetched_balance: 100)

      params = %{
        "module" => "account",
        "action" => "balancemulti",
        "address" => "#{address.hash}"
      }

      expected_balance =
        address.fetched_balance
        |> Wei.to(:ether)
        |> Decimal.to_string(:normal)

      expected_result = [
        %{"account" => "#{address.hash}", "balance" => expected_balance}
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
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
               |> json_response(400)

      assert response["message"] =~ "'address' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
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
               |> json_response(400)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
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

      {:ok, max_block_number} = Chain.max_block_number()
      expected_confirmations = max_block_number - transaction.block_number

      assert %{"result" => [returned_transaction]} =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert returned_transaction["confirmations"] == "#{expected_confirmations}"
      assert returned_transaction["hash"] == "#{hash}"
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
               conn
               |> get("/api", params)
               |> json_response(200)

      assert returned_transaction["isError"] == "1"
      assert returned_transaction["txreceipt_status"] == "0"
      assert returned_transaction["hash"] == "#{hash}"
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
    end
  end
end
