defmodule BlockScoutWeb.API.RPC.TokenControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Log, Transaction}

  describe "gettoken" do
    test "with missing contract address", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "getToken"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contract address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contract address hash", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "getToken",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contract address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a contract address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "getToken",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contract address not found"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "response includes all required fields", %{conn: conn} do
      token = insert(:token)

      params = %{
        "module" => "token",
        "action" => "getToken",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      expected_result = %{
        "name" => token.name,
        "symbol" => token.symbol,
        "totalSupply" => to_string(token.total_supply),
        "decimals" => to_string(token.decimals),
        "type" => token.type,
        "cataloged" => token.cataloged,
        "contractAddress" => to_string(token.contract_address_hash)
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

  describe "tokentx" do
    test "with missing required parameters", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokentx"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Required query parameters missing: contractaddress, fromBlock, toBlock"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contractaddress hash", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokentx",
        "fromBlock" => "1",
        "toBlock" => "3",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid fromBlock value", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokentx",
        "fromBlock" => "invalid",
        "toBlock" => "3",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid fromBlock format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid toBlock value", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokentx",
        "fromBlock" => "1",
        "toBlock" => "invalid",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid toBlock format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a contractaddress that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokentx",
        "fromBlock" => "1",
        "toBlock" => "3",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contractaddress not found"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "successful case with logs", %{conn: conn} do
      contract_address = insert(:contract_address)
      insert(:token, contract_address: contract_address)
      address = insert(:address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        from_address: contract_address,
        to_address: address,
        token_contract_address: contract_address,
        block: transaction.block,
        token_id: 10
      )

      log = insert(:log, address: contract_address, transaction: transaction)

      params = %{
        "module" => "token",
        "action" => "tokentx",
        "fromBlock" => "0",
        "toBlock" => "latest",
        "contractaddress" => "#{contract_address.hash}"
      }

      expected_result = [
        %{
          "address" => "#{contract_address.hash}",
          "topics" => get_topics(log),
          "data" => "#{log.data}",
          "blockNumber" => integer_to_hex(transaction.block_number),
          "timeStamp" => datetime_to_hex(block.timestamp),
          "gasPrice" => decimal_to_hex(transaction.gas_price.value),
          "gasUsed" => decimal_to_hex(transaction.gas_used),
          "gatewayFeeRecipient" => "",
          "gatewayFee" => "",
          "feeCurrency" => "",
          "logIndex" => integer_to_hex(log.index),
          "transactionHash" => "#{transaction.hash}",
          "transactionIndex" => integer_to_hex(transaction.index),
          "amount" => "1",
          "fromAddressHash" => "#{contract_address.hash}",
          "toAddressHash" => "#{address.hash}"
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

    test "successful case without logs", %{conn: conn} do
      contract_address = insert(:contract_address)
      insert(:token, contract_address: contract_address)
      address = insert(:address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        from_address: contract_address,
        to_address: address,
        token_contract_address: contract_address,
        block: transaction.block,
        token_id: 10
      )

      params = %{
        "module" => "token",
        "action" => "tokentx",
        "fromBlock" => "0",
        "toBlock" => "latest",
        "contractaddress" => "#{contract_address.hash}"
      }

      expected_result = [
        %{
          "address" => "#{contract_address.hash}",
          "topics" => [nil, nil, nil, nil],
          "data" => "",
          "blockNumber" => integer_to_hex(transaction.block_number),
          "timeStamp" => datetime_to_hex(block.timestamp),
          "gasPrice" => decimal_to_hex(transaction.gas_price.value),
          "gasUsed" => decimal_to_hex(transaction.gas_used),
          "gatewayFeeRecipient" => "",
          "gatewayFee" => "",
          "feeCurrency" => "",
          "logIndex" => "",
          "transactionHash" => "#{transaction.hash}",
          "transactionIndex" => integer_to_hex(transaction.index),
          "amount" => "1",
          "fromAddressHash" => "#{contract_address.hash}",
          "toAddressHash" => "#{address.hash}"
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
  end

  defp get_topics(%Log{
         first_topic: first_topic,
         second_topic: second_topic,
         third_topic: third_topic,
         fourth_topic: fourth_topic
       }) do
    [first_topic, second_topic, third_topic, fourth_topic]
  end

  defp integer_to_hex(nil), do: ""
  defp integer_to_hex(integer), do: Integer.to_string(integer, 16)

  defp decimal_to_hex(decimal) do
    decimal
    |> Decimal.to_integer()
    |> integer_to_hex()
  end

  defp datetime_to_hex(datetime) do
    datetime
    |> DateTime.to_unix()
    |> integer_to_hex()
  end
  # defp gettoken_schema do
  #   ExJsonSchema.Schema.resolve(%{
  #     "type" => "object",
  #     "properties" => %{
  #       "message" => %{"type" => "string"},
  #       "status" => %{"type" => "string"},
  #       "result" => %{
  #         "type" => "object",
  #         "properties" => %{
  #           "name" => %{"type" => "string"},
  #           "symbol" => %{"type" => "string"},
  #           "totalSupply" => %{"type" => "string"},
  #           "decimals" => %{"type" => "string"},
  #           "type" => %{"type" => "string"},
  #           "cataloged" => %{"type" => "string"},
  #           "contractAddress" => %{"type" => "string"}
  #         }
  #       }
  #     }
  #   })
  # end
end
