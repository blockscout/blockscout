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

    test "supports GET and POST requests", %{conn: conn} do
      address = insert(:address, fetched_balance: 100)

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

    test "supports GET and POST requests", %{conn: conn} do
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

      assert block_numbers_order == Enum.sort(block_numbers_order, &(&1 <= &2))
      assert response["status"] == "1"
      assert response["message"] == "OK"
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

      _third_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(third_block)

      first_block_transactions =
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
    end

    test "ignores pagination params if page is less than 1", %{conn: conn} do
      address = insert(:address)

      6
      |> insert_list(:transaction, from_address: address)
      |> with_block()

      params = %{
        "module" => "account",
        "action" => "txlist",
        "address" => "#{address.hash}",
        # page number
        "page" => "0",
        # page size
        "offset" => "2"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(response["result"]) == 6
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "ignores pagination params if offset is less than 1", %{conn: conn} do
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
    end

    test "ignores pagination params if offset is over 10,000", %{conn: conn} do
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
end
