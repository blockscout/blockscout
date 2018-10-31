defmodule BlockScoutWeb.API.RPC.TransactionControllerTest do
  use BlockScoutWeb.ConnCase

  describe "gettxreceiptstatus" do
    test "with missing txhash", %{conn: conn} do
      params = %{
        "module" => "transaction",
        "action" => "gettxreceiptstatus"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "txhash is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid txhash", %{conn: conn} do
      params = %{
        "module" => "transaction",
        "action" => "gettxreceiptstatus",
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
    end

    test "with a txhash that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "transaction",
        "action" => "gettxreceiptstatus",
        "txhash" => "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == %{"status" => ""}
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with ok status", %{conn: conn} do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: :ok)

      params = %{
        "module" => "transaction",
        "action" => "gettxreceiptstatus",
        "txhash" => "#{transaction.hash}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == %{"status" => "1"}
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with error status", %{conn: conn} do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: :error)

      params = %{
        "module" => "transaction",
        "action" => "gettxreceiptstatus",
        "txhash" => "#{transaction.hash}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == %{"status" => "0"}
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with nil status", %{conn: conn} do
      transaction = insert(:transaction, status: nil)

      params = %{
        "module" => "transaction",
        "action" => "gettxreceiptstatus",
        "txhash" => "#{transaction.hash}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == %{"status" => ""}
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end

  describe "getstatus" do
    test "with missing txhash", %{conn: conn} do
      params = %{
        "module" => "transaction",
        "action" => "getstatus"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "txhash is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid txhash", %{conn: conn} do
      params = %{
        "module" => "transaction",
        "action" => "getstatus",
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
    end

    test "with a txhash that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "transaction",
        "action" => "getstatus",
        "txhash" => "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
      }

      expected_result = %{
        "isError" => "0",
        "errDescription" => ""
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with ok status", %{conn: conn} do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: :ok)

      params = %{
        "module" => "transaction",
        "action" => "getstatus",
        "txhash" => "#{transaction.hash}"
      }

      expected_result = %{
        "isError" => "0",
        "errDescription" => ""
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with error", %{conn: conn} do
      error = "some error"

      transaction_details = [
        status: :error,
        error: error,
        internal_transactions_indexed_at: DateTime.utc_now()
      ]

      transaction =
        :transaction
        |> insert()
        |> with_block(transaction_details)

      internal_transaction_details = [
        transaction: transaction,
        index: 0,
        type: :reward,
        error: error
      ]

      insert(:internal_transaction, internal_transaction_details)

      params = %{
        "module" => "transaction",
        "action" => "getstatus",
        "txhash" => "#{transaction.hash}"
      }

      expected_result = %{
        "isError" => "1",
        "errDescription" => error
      }

      response =
        conn
        |> get("/api", params)
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with failed status but awaiting internal transactions", %{conn: conn} do
      transaction_details = [
        status: :error,
        error: nil,
        internal_transactions_indexed_at: nil
      ]

      transaction =
        :transaction
        |> insert()
        |> with_block(transaction_details)

      params = %{
        "module" => "transaction",
        "action" => "getstatus",
        "txhash" => "#{transaction.hash}"
      }

      expected_result = %{
        "isError" => "1",
        "errDescription" => "awaiting internal transactions"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with nil status", %{conn: conn} do
      transaction = insert(:transaction, status: nil)

      params = %{
        "module" => "transaction",
        "action" => "getstatus",
        "txhash" => "#{transaction.hash}"
      }

      expected_result = %{
        "isError" => "0",
        "errDescription" => ""
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end

  describe "gettxinfo" do
    test "with missing txhash", %{conn: conn} do
      params = %{
        "module" => "transaction",
        "action" => "gettxinfo"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "txhash is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid txhash", %{conn: conn} do
      params = %{
        "module" => "transaction",
        "action" => "gettxinfo",
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
    end

    test "with a txhash that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "transaction",
        "action" => "gettxinfo",
        "txhash" => "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Transaction not found"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a txhash with ok status", %{conn: conn} do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: :ok)

      address = insert(:address)
      insert(:log, address: address, transaction: transaction)

      params = %{
        "module" => "transaction",
        "action" => "gettxinfo",
        "txhash" => "#{transaction.hash}"
      }

      expected_result =     %{
        "hash" => "#{transaction.hash}",
        "timeStamp" => "#{DateTime.to_unix(transaction.block.timestamp)}",
        "blockNumber" => "#{transaction.block_number}",
        "confirmations" => "0",
        "success" => true,
        "from" => "#{transaction.from_address_hash}",
        "to" => "#{transaction.to_address_hash}",
        "value" => "#{transaction.value.value}",
        "input" => "#{transaction.input}",
        "gasLimit" => "#{transaction.gas}",
        "gasUsed" => "#{transaction.gas_used}",
        "logs" => [%{
          "address" => "#{address}",
          "data" => "0x00",
          "topics" => [nil, nil, nil, nil]
        }]
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end
end
