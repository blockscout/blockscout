defmodule BlockScoutWeb.API.RPC.TransactionControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  @moduletag capture_log: true

  @first_topic_hex_string_1 "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65"
  @second_topic_hex_string_1 "0x00000000000000000000000098a9dc37d3650b5b30d6c12789b3881ee0b70c16"

  setup :verify_on_exit!

  defp topic(topic_hex_string) do
    {:ok, topic} = Explorer.Chain.Hash.Full.cast(topic_hex_string)
    topic
  end

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

      schema = resolve_schema()
      assert ExJsonSchema.Validator.valid?(schema, response)
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

      schema = resolve_schema()
      assert ExJsonSchema.Validator.valid?(schema, response)
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

      schema =
        resolve_schema(%{
          "type" => "object",
          "properties" => %{
            "status" => %{"type" => "string"}
          }
        })

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert ExJsonSchema.Validator.valid?(schema, response)
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

      schema = resolve_schema()
      assert ExJsonSchema.Validator.valid?(schema, response)
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

      schema = resolve_schema()
      assert ExJsonSchema.Validator.valid?(schema, response)
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

      schema =
        resolve_schema(%{
          "type" => "object",
          "properties" => %{
            "isError" => %{"type" => "string"},
            "errDescription" => %{"type" => "string"}
          }
        })

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert ExJsonSchema.Validator.valid?(schema, response)
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
        error: error
      ]

      transaction =
        :transaction
        |> insert()
        |> with_block(transaction_details)

      internal_transaction_details = [
        transaction: transaction,
        index: 0,
        type: :reward,
        error: error,
        block_hash: transaction.block_hash,
        block_index: 0
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
        error: nil
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

      schema = resolve_schema()
      assert ExJsonSchema.Validator.valid?(schema, response)
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

    test "paginates logs", %{conn: conn} do
      block = insert(:block, hash: "0x30d522bcf2d8e0cabc286e6e40623c475c3bc05d0ec484ea239c103b1ac0ded9", number: 99)

      transaction =
        :transaction
        |> insert(hash: "0x13b6bb8e06322096dc83e8d7e6332ca19919ea642212cd259c6b20e7523a0599")
        |> with_block(block, status: :ok)

      address = insert(:address)

      Enum.each(1..100, fn _ ->
        insert(:log,
          address: address,
          transaction: transaction,
          first_topic: topic(@first_topic_hex_string_1),
          second_topic: topic(@second_topic_hex_string_1),
          block: block,
          block_number: block.number
        )
      end)

      params1 = %{
        "module" => "transaction",
        "action" => "gettxinfo",
        "txhash" => "#{transaction.hash}"
      }

      schema =
        resolve_schema(%{
          "type" => "object",
          "properties" => %{
            "next_page_params" => %{
              "type" => ["object", "null"],
              "properties" => %{
                "action" => %{"type" => "string"},
                "index" => %{"type" => "number"},
                "module" => %{"type" => "string"},
                "txhash" => %{"type" => "string"}
              }
            },
            "logs" => %{
              "type" => "array",
              "items" => %{"type" => "object"}
            }
          }
        })

      assert response1 =
               conn
               |> get("/api", params1)
               |> json_response(200)

      assert ExJsonSchema.Validator.valid?(schema, response1)
      assert response1["status"] == "1"
      assert response1["message"] == "OK"

      assert %{
               "action" => "gettxinfo",
               "index" => _,
               "module" => "transaction",
               "txhash" => _
             } = response1["result"]["next_page_params"]

      params2 = response1["result"]["next_page_params"]

      assert response2 =
               conn
               |> get("/api", params2)
               |> json_response(200)

      assert ExJsonSchema.Validator.valid?(schema, response2)
      assert response2["status"] == "1"
      assert response2["message"] == "OK"
      assert is_nil(response2["result"]["next_page_params"])
      assert response1["result"]["logs"] != response2["result"]["logs"]
    end

    test "with a txhash with ok status", %{conn: conn} do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: :ok)

      address = insert(:address)

      log =
        insert(:log,
          address: address,
          transaction: transaction,
          first_topic: topic(@first_topic_hex_string_1),
          second_topic: topic(@second_topic_hex_string_1),
          block: block,
          block_number: block.number
        )

      params = %{
        "module" => "transaction",
        "action" => "gettxinfo",
        "txhash" => "#{transaction.hash}"
      }

      expected_result = %{
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
        "gasPrice" => "#{transaction.gas_price.value}",
        "logs" => [
          %{
            "address" => "#{address.hash}",
            "data" => "#{log.data}",
            "topics" => [@first_topic_hex_string_1, @second_topic_hex_string_1, nil, nil],
            "index" => "#{log.index}"
          }
        ],
        "next_page_params" => nil,
        "revertReason" => ""
      }

      schema =
        resolve_schema(%{
          "type" => "object",
          "properties" => %{
            "hash" => %{"type" => "string"},
            "timeStamp" => %{"type" => "string"},
            "blockNumber" => %{"type" => "string"},
            "confirmations" => %{"type" => "string"},
            "success" => %{"type" => "boolean"},
            "from" => %{"type" => "string"},
            "to" => %{"type" => "string"},
            "value" => %{"type" => "string"},
            "input" => %{"type" => "string"},
            "gasLimit" => %{"type" => "string"},
            "gasUsed" => %{"type" => "string"},
            "gasPrice" => %{"type" => "string"},
            "logs" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "properties" => %{
                  "address" => %{"type" => "string"},
                  "data" => %{"type" => "string"},
                  "topics" => %{
                    "type" => "array",
                    "items" => %{"type" => ["string", "null"]}
                  },
                  "index" => %{"type" => "string"}
                }
              }
            },
            "next_page_params" => %{
              "type" => ["object", "null"],
              "properties" => %{
                "action" => %{"type" => "string"},
                "index" => %{"type" => "number"},
                "module" => %{"type" => "string"},
                "txhash" => %{"type" => "string"}
              }
            }
          }
        })

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert ExJsonSchema.Validator.valid?(schema, response)
      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with revert reason from DB", %{conn: conn} do
      block = insert(:block, number: 100)

      transaction =
        :transaction
        |> insert(revert_reason: "No credit of that type")
        |> with_block(block)

      insert(:address)

      params = %{
        "module" => "transaction",
        "action" => "gettxinfo",
        "txhash" => "#{transaction.hash}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"]["revertReason"] == "No credit of that type"
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with empty revert reason from DB", %{conn: conn} do
      block = insert(:block, number: 100)

      transaction =
        :transaction
        |> insert(revert_reason: "")
        |> with_block(block)

      insert(:address)

      params = %{
        "module" => "transaction",
        "action" => "gettxinfo",
        "txhash" => "#{transaction.hash}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"]["revertReason"] == ""
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "with a txhash with revert reason from the archive node", %{conn: conn} do
      block = insert(:block, number: 100, hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391")

      transaction =
        :transaction
        |> insert(
          error: "Reverted",
          status: :error,
          block_hash: block.hash,
          block_number: block.number,
          cumulative_gas_used: 884_322,
          gas_used: 106_025,
          index: 0,
          hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269"
        )

      insert(:address)

      # Error("No credit of that type")
      hex_reason =
        "0x08c379a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000164e6f20637265646974206f662074686174207479706500000000000000000000"

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn
          [%{method: "debug_traceTransaction"}], _options ->
            {:ok,
             [
               %{
                 id: 0,
                 result: %{
                   "from" => "0x6a17ca3bbf83764791f4a9f2b4dbbaebbc8b3e0d",
                   "gas" => "0x5208",
                   "gasUsed" => "0x5208",
                   "input" => "0x01",
                   "output" => hex_reason,
                   "to" => "0x7ed1e469fcb3ee19c0366d829e291451be638e59",
                   "type" => "CALL",
                   "value" => "0x86b3"
                 }
               }
             ]}

          [%{method: "trace_replayTransaction"}], _options ->
            {:ok,
             [
               %{
                 id: 0,
                 result: %{
                   "output" => "0x",
                   "stateDiff" => nil,
                   "trace" => [
                     %{
                       "action" => %{
                         "callType" => "call",
                         "from" => "0x6a17ca3bbf83764791f4a9f2b4dbbaebbc8b3e0d",
                         "gas" => "0x5208",
                         "input" => "0x01",
                         "to" => "0x7ed1e469fcb3ee19c0366d829e291451be638e59",
                         "value" => "0x86b3"
                       },
                       "error" => "Reverted",
                       "result" => %{
                         "gasUsed" => "0x5208",
                         "output" => hex_reason
                       },
                       "subtraces" => 0,
                       "traceAddress" => [],
                       "type" => "call"
                     }
                   ],
                   "transactionHash" => "0xdf5574290913659a1ac404ccf2d216c40587f819400a52405b081dda728ac120",
                   "vmTrace" => nil
                 }
               }
             ]}

          %{method: "eth_call"}, _options ->
            {:error,
             %{
               code: 3,
               data: hex_reason,
               message: "execution reverted"
             }}
        end
      )

      params = %{
        "module" => "transaction",
        "action" => "gettxinfo",
        "txhash" => "#{transaction.hash}"
      }

      init_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"]["revertReason"] == hex_reason
      assert response["status"] == "1"
      assert response["message"] == "OK"

      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, init_config)
    end
  end

  test "with a txhash with empty revert reason from the archive node", %{conn: conn} do
    block = insert(:block, number: 100, hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391")

    transaction =
      :transaction
      |> insert(
        error: "Reverted",
        status: :error,
        block_hash: block.hash,
        block_number: block.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269"
      )

    insert(:address)

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn
        [%{method: "debug_traceTransaction"}], _options ->
          {:ok,
           [
             %{
               id: 0,
               result: %{
                 "error" => "Reverted",
                 "from" => "0x6a17ca3bbf83764791f4a9f2b4dbbaebbc8b3e0d",
                 "gas" => "0x5208",
                 "gasUsed" => "0x5208",
                 "input" => "0x01",
                 "to" => "0x7ed1e469fcb3ee19c0366d829e291451be638e59",
                 "type" => "CALL",
                 "value" => "0x86b3"
               }
             }
           ]}

        [%{method: "trace_replayTransaction"}], _options ->
          {:ok,
           [
             %{
               id: 0,
               result: %{
                 "output" => "0x",
                 "stateDiff" => nil,
                 "trace" => [
                   %{
                     "action" => %{
                       "callType" => "call",
                       "from" => "0x6a17ca3bbf83764791f4a9f2b4dbbaebbc8b3e0d",
                       "gas" => "0x5208",
                       "input" => "0x01",
                       "to" => "0x7ed1e469fcb3ee19c0366d829e291451be638e59",
                       "value" => "0x86b3"
                     },
                     "error" => "Reverted",
                     "result" => %{
                       "gasUsed" => "0x5208",
                       "output" => "0x"
                     },
                     "subtraces" => 0,
                     "traceAddress" => [],
                     "type" => "call"
                   }
                 ],
                 "transactionHash" => "0xdf5574290913659a1ac404ccf2d216c40587f819400a52405b081dda728ac120",
                 "vmTrace" => nil
               }
             }
           ]}

        %{method: "eth_call"}, _options ->
          {:error,
           %{
             code: 3,
             message: "execution reverted"
           }}
      end
    )

    params = %{
      "module" => "transaction",
      "action" => "gettxinfo",
      "txhash" => "#{transaction.hash}"
    }

    init_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
    Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, tracer: "call_tracer", debug_trace_timeout: "5s")

    assert response =
             conn
             |> get("/api", params)
             |> json_response(200)

    assert response["result"]["revertReason"] in ["", "0x"]
    assert response["status"] == "1"
    assert response["message"] == "OK"

    Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, init_config)
  end

  defp resolve_schema(result \\ %{}) do
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
