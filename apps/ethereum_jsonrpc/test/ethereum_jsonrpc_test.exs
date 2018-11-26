defmodule EthereumJSONRPCTest do
  use EthereumJSONRPC.Case, async: true

  import EthereumJSONRPC.Case
  import Mox

  alias EthereumJSONRPC.{Blocks, FetchedBalances, FetchedBeneficiaries, Subscription}
  alias EthereumJSONRPC.WebSocket.WebSocketClient

  setup :verify_on_exit!

  @moduletag :capture_log

  describe "fetch_balances/1" do
    test "with all valid hash_data returns {:ok, addresses_params}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      expected_fetched_balance =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Geth -> 0
          EthereumJSONRPC.Parity -> 1
          variant -> raise ArgumentError, "Unsupported variant (#{variant}})"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, [%{id: 0, result: EthereumJSONRPC.integer_to_quantity(expected_fetched_balance)}]}
        end)
      end

      hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"

      assert EthereumJSONRPC.fetch_balances(
               [
                 %{block_quantity: "0x1", hash_data: hash}
               ],
               json_rpc_named_arguments
             ) ==
               {:ok,
                %FetchedBalances{
                  params_list: [
                    %{
                      address_hash: hash,
                      block_number: 1,
                      value: expected_fetched_balance
                    }
                  ]
                }}
    end

    test "with all invalid hash_data returns errors", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      expected_message =
        case variant do
          EthereumJSONRPC.Geth ->
            "invalid argument 0: json: cannot unmarshal hex string of odd length into Go value of type common.Address"

          EthereumJSONRPC.Parity ->
            "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."

          _ ->
            raise ArgumentError, "Unsupported variant (#{variant}})"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               error: %{
                 code: -32602,
                 message: expected_message
               }
             }
           ]}
        end)
      end

      assert {:ok,
              %FetchedBalances{
                errors: [
                  %{
                    code: -32602,
                    data: %{hash_data: "0x0", block_quantity: "0x1"},
                    message: ^expected_message
                  }
                ],
                params_list: []
              }} =
               EthereumJSONRPC.fetch_balances([%{block_quantity: "0x1", hash_data: "0x0"}], json_rpc_named_arguments)
    end

    test "with a mix of valid and invalid hash_data returns both", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {
            :ok,
            [
              %{
                id: 0,
                result: "0x0"
              },
              %{
                id: 1,
                result: "0x1"
              },
              %{
                id: 2,
                error: %{
                  code: -32602,
                  message:
                    "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                }
              },
              %{
                id: 3,
                result: "0x3"
              },
              %{
                id: 4,
                error: %{
                  code: -32602,
                  message:
                    "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                }
              }
            ]
          }
        end)
      end

      assert {:ok, %FetchedBalances{params_list: params_list, errors: errors}} =
               EthereumJSONRPC.fetch_balances(
                 [
                   # start with :ok
                   %{
                     block_quantity: "0x1",
                     hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                   },
                   # :ok, :ok clause
                   %{
                     block_quantity: "0x34",
                     hash_data: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
                   },
                   # :ok, :error clause
                   %{
                     block_quantity: "0x2",
                     hash_data: "0x3"
                   },
                   # :error, :ok clause
                   %{
                     block_quantity: "0x35",
                     hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                   },
                   # :error, :error clause
                   %{
                     block_quantity: "0x4",
                     hash_data: "0x5"
                   }
                 ],
                 json_rpc_named_arguments
               )

      assert is_list(params_list)
      assert length(params_list) > 1

      assert is_list(errors)
      assert length(errors) > 1
    end
  end

  describe "fetch_beneficiaries/2" do
    @tag :no_geth
    test "fetches benefeciaries from variant API", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
          {:ok, []}
        end)

        assert EthereumJSONRPC.fetch_beneficiaries(1..1, json_rpc_named_arguments) ==
                 {:ok, %FetchedBeneficiaries{params_set: MapSet.new(), errors: []}}
      end
    end
  end

  describe "fetch_block_by_hash/2" do
    test "can fetch blocks", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{block_hash: block_hash, transaction_hash: transaction_hash} =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Parity ->
            %{
              block_hash: "0x29c850324e357f3c0c836d79860c5af55f7b651e5d7ee253c1af1b14908af49c",
              transaction_hash: "0xa2e81bb56b55ba3dab2daf76501b50dfaad240cccb905dbf89d65c7a84a4a48e"
            }

          EthereumJSONRPC.Geth ->
            %{
              block_hash: "0xe065eed62c152c8c3dd14d6e5948e652c3e36a9cdb10b79853802ef9fa1d536c",
              transaction_hash: "0x615506d9872bb07faa2ce17c02b902148eae88ccba0298902be6a0dbba1124de"
            }
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id}], _options ->
          block_number = "0x0"

          {:ok,
           [
             %{
               id: id,
               result: %{
                 "difficulty" => "0x0",
                 "gasLimit" => "0x0",
                 "gasUsed" => "0x0",
                 "hash" => block_hash,
                 "extraData" => "0x0",
                 "logsBloom" => "0x0",
                 "miner" => "0x0",
                 "number" => block_number,
                 "parentHash" => "0x0",
                 "receiptsRoot" => "0x0",
                 "size" => "0x0",
                 "sha3Uncles" => "0x0",
                 "stateRoot" => "0x0",
                 "timestamp" => "0x0",
                 "totalDifficulty" => "0x0",
                 "transactions" => [
                   %{
                     "blockHash" => block_hash,
                     "blockNumber" => block_number,
                     "from" => "0x0",
                     "gas" => "0x0",
                     "gasPrice" => "0x0",
                     "hash" => transaction_hash,
                     "input" => "0x",
                     "nonce" => "0x0",
                     "r" => "0x0",
                     "s" => "0x0",
                     "to" => "0x0",
                     "transactionIndex" => "0x0",
                     "v" => "0x0",
                     "value" => "0x0"
                   }
                 ],
                 "transactionsRoot" => "0x0",
                 "uncles" => []
               }
             }
           ]}
        end)
      end

      assert {:ok, %Blocks{blocks_params: [_ | _], transactions_params: [_ | _]}} =
               EthereumJSONRPC.fetch_blocks_by_hash([block_hash], json_rpc_named_arguments)
    end

    test "returns errors with block hash in data", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               error: %{
                 code: -32602,
                 message: "Hash too short"
               },
               id: 0,
               jsonrpc: "2.0"
             }
           ]}
        end)
      end

      hash = "0x0"

      assert {:ok,
              %Blocks{
                errors: [
                  %{
                    data: %{
                      hash: ^hash
                    }
                  }
                ]
              }} = EthereumJSONRPC.fetch_blocks_by_hash([hash], json_rpc_named_arguments)
    end

    test "full batch errors are returned", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      # I'm not sure how to reliably trigger this on the real chains, so only do mox
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      error = {:error, %{"message" => "methodNotSupported"}}

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        error
      end)

      assert EthereumJSONRPC.fetch_blocks_by_hash(["0x0"], moxed_json_rpc_named_arguments) == error
    end
  end

  describe "fetch_block_by_range/2" do
    test "returns errors with block number in data", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               error: %{
                 code: -32602,
                 message: "Invalid params: Invalid block number: number too large to fit in target type."
               },
               id: 0,
               jsonrpc: "2.0"
             },
             %{
               error: %{
                 code: -32602,
                 message: "Invalid params: Invalid block number: number too large to fit in target type."
               },
               id: 1,
               jsonrpc: "2.0"
             }
           ]}
        end)
      end

      assert {:ok,
              %EthereumJSONRPC.Blocks{
                block_second_degree_relations_params: [],
                blocks_params: [],
                errors: [
                  %{
                    data: %{number: 1_000_000_000_000_000_000_001}
                  },
                  %{
                    data: %{number: 1_000_000_000_000_000_000_000}
                  }
                ],
                transactions_params: []
              }} =
               EthereumJSONRPC.fetch_blocks_by_range(
                 1_000_000_000_000_000_000_000..1_000_000_000_000_000_000_001,
                 json_rpc_named_arguments
               )
    end

    test "returns only errors and results if a mix of results and errors", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      # Can't be faked reliably on real chain
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok,
         [
           %{
             error: %{
               code: -32602,
               message: "Invalid params: Invalid block number: number too large to fit in target type."
             },
             id: 0,
             jsonrpc: "2.0"
           },
           %{
             id: 1,
             result: %{
               "difficulty" => "0x0",
               "extraData" => "0x",
               "gasLimit" => "0x0",
               "gasUsed" => "0x0",
               "hash" => "0x0",
               "logsBloom" => "0x",
               "miner" => "0x0",
               "number" => "0x0",
               "parentHash" => "0x0",
               "receiptsRoot" => "0x0",
               "sha3Uncles" => "0x0",
               "size" => "0x0",
               "stateRoot" => "0x0",
               "timestamp" => "0x0",
               "totalDifficulty" => "0x0",
               "transactions" => [],
               "transactionsRoot" => [],
               "uncles" => []
             },
             jsonrpc: "2.0"
           }
         ]}
      end)

      assert {:ok,
              %EthereumJSONRPC.Blocks{
                block_second_degree_relations_params: [],
                blocks_params: [
                  %{
                    difficulty: 0,
                    extra_data: "0x",
                    gas_limit: 0,
                    gas_used: 0,
                    hash: "0x0",
                    logs_bloom: "0x",
                    miner_hash: "0x0",
                    mix_hash: "0x0",
                    nonce: 0,
                    number: 0,
                    parent_hash: "0x0",
                    receipts_root: "0x0",
                    sha3_uncles: "0x0",
                    size: 0,
                    state_root: "0x0",
                    timestamp: _,
                    total_difficulty: 0,
                    transactions_root: [],
                    uncles: []
                  }
                ],
                errors: [
                  %{
                    code: -32602,
                    data: %{number: 1_000_000_000_000_000_000_000},
                    message: "Invalid params: Invalid block number: number too large to fit in target type."
                  }
                ],
                transactions_params: []
              }} =
               EthereumJSONRPC.fetch_blocks_by_range(
                 1_000_000_000_000_000_000_000..1_000_000_000_000_000_000_001,
                 moxed_json_rpc_named_arguments
               )
    end

    test "nil result indicated error code 404", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      # Can't be faked reliably on real chain
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok,
         [
           %{
             id: 0,
             result: %{
               "difficulty" => "0x0",
               "extraData" => "0x0",
               "gasLimit" => "0x0",
               "gasUsed" => "0x0",
               "hash" => "0x0",
               "logsBloom" => "0x0",
               "miner" => "0x0",
               "number" => "0x0",
               "parentHash" => "0x0",
               "receiptsRoot" => "0x0",
               "sha3Uncles" => "0x0",
               "size" => "0x0",
               "stateRoot" => "0x0",
               "timestamp" => "0x0",
               "totalDifficulty" => "0x0",
               "transactions" => [],
               "transactionsRoot" => "0x0",
               "uncles" => []
             },
             jsonrpc: "2.0"
           },
           %{
             result: nil,
             id: 1,
             jsonrpc: "2.0"
           }
         ]}
      end)

      assert {:ok,
              %EthereumJSONRPC.Blocks{
                block_second_degree_relations_params: [],
                blocks_params: [%{}],
                errors: [%{code: 404, data: %{number: 1}, message: "Not Found"}],
                transactions_params: []
              }} = EthereumJSONRPC.fetch_blocks_by_range(0..1, moxed_json_rpc_named_arguments)
    end
  end

  describe "fetch_block_number_by_tag" do
    @tag capture_log: false
    test "with earliest", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, %{"number" => "0x0"}}
        end)
      end

      log_bad_gateway(
        fn -> EthereumJSONRPC.fetch_block_number_by_tag("earliest", json_rpc_named_arguments) end,
        fn result ->
          assert {:ok, 0} = result
        end
      )
    end

    @tag capture_log: false
    test "with latest", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, %{"number" => "0x1"}}
        end)
      end

      log_bad_gateway(
        fn -> EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments) end,
        fn result ->
          assert {:ok, number} = result
          assert number > 0
        end
      )
    end

    @tag capture_log: false
    test "with pending", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, nil}
        end)
      end

      log_bad_gateway(
        fn -> EthereumJSONRPC.fetch_block_number_by_tag("pending", json_rpc_named_arguments) end,
        fn
          # Parity after https://github.com/paritytech/parity-ethereum/pull/8281 and anything spec-compliant
          {:error, reason} ->
            assert reason == :not_found

          # Parity before https://github.com/paritytech/parity-ethereum/pull/8281
          {:ok, number} ->
            assert is_integer(number)
            assert number > 0
        end
      )
    end

    test "unknown errors are returned", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      # Can't be faked reliably on real chain
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      unknown_error = {:error, %{"code" => 500, "message" => "Unknown error"}}

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        unknown_error
      end)

      assert {:error, unknown_error} =
               EthereumJSONRPC.fetch_block_number_by_tag("latest", moxed_json_rpc_named_arguments)
    end
  end

  describe "fetch_pending_transactions/2" do
    @tag :no_geth
    test "pending transactions are returned", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               "blockHash" => nil,
               "blockNumber" => nil,
               "from" => "0x0",
               "gas" => "0x0",
               "gasPrice" => "0x0",
               "hash" => "0x73c5599001f77bd570e32c4a5e63157200747910a502fae009821767c36b2ac9",
               "input" => "0x",
               "nonce" => "0x0",
               "r" => "0x0",
               "s" => "0x0",
               "to" => "0x0",
               "transactionIndex" => nil,
               "v" => "0x0",
               "value" => "0x0"
             }
           ]}
        end)
      end

      assert {:ok, pending_transactions} = EthereumJSONRPC.fetch_pending_transactions(json_rpc_named_arguments)
      # can't say more because there could be no pending transactions on test chains
      assert is_list(pending_transactions)
    end
  end

  describe "fetch_transaction_receipts/2" do
    test "with invalid transaction hash", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      hash = "0x0000000000000000000000000000000000000000000000000000000000000000"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, [%{id: 0, jsonrpc: "2.0", result: nil}]}
        end)
      end

      assert {:error, [%{data: %{hash: ^hash}, message: "Not Found"}]} =
               EthereumJSONRPC.fetch_transaction_receipts(
                 [%{hash: hash, gas: "0x0"}],
                 json_rpc_named_arguments
               )
    end

    test "with valid transaction hash", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      hash =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Parity ->
            "0xa2e81bb56b55ba3dab2daf76501b50dfaad240cccb905dbf89d65c7a84a4a48e"

          EthereumJSONRPC.Geth ->
            "0x615506d9872bb07faa2ce17c02b902148eae88ccba0298902be6a0dbba1124de"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "blockHash" => "0x29c850324e357f3c0c836d79860c5af55f7b651e5d7ee253c1af1b14908af49c",
                 "blockNumber" => "0x414911",
                 "contractAddress" => nil,
                 "cumulativeGasUsed" => "0x5208",
                 "gasUsed" => "0x5208",
                 "logs" => [],
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "root" => nil,
                 "status" => "0x1",
                 "transactionHash" => hash,
                 "transactionIndex" => "0x0"
               }
             }
           ]}
        end)
      end

      assert {:ok, %{logs: logs, receipts: [_]}} =
               EthereumJSONRPC.fetch_transaction_receipts([%{hash: hash, gas: "0x0"}], json_rpc_named_arguments)

      assert is_list(logs)
    end
  end

  describe "subscribe/2" do
    test "can subscribe to newHeads", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      subscription_transport_options =
        case transport do
          EthereumJSONRPC.Mox ->
            expect(transport, :subscribe, fn "newHeads", [], _ ->
              {:ok,
               %Subscription{
                 reference: make_ref(),
                 subscriber_pid: subscriber_pid,
                 transport: transport,
                 transport_options: transport_options
               }}
            end)

            transport_options

          EthereumJSONRPC.WebSocket ->
            update_in(transport_options.web_socket_options, fn %WebSocketClient.Options{} = web_socket_options ->
              %WebSocketClient.Options{web_socket_options | event: "newHeads", params: []}
            end)
        end

      assert {:ok,
              %Subscription{
                reference: subscription_reference,
                subscriber_pid: ^subscriber_pid,
                transport: ^transport,
                transport_options: ^subscription_transport_options
              }} = EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments)

      assert is_reference(subscription_reference)
    end

    # Infura timeouts on 2018-09-12
    @tag :no_geth
    test "delivers new heads to caller", %{
      block_interval: block_interval,
      subscribe_named_arguments: subscribe_named_arguments
    } do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        expect(transport, :subscribe, fn _, _, _ ->
          subscription = %Subscription{
            reference: make_ref(),
            subscriber_pid: subscriber_pid,
            transport: transport,
            transport_options: transport_options
          }

          Process.send_after(subscriber_pid, {subscription, {:ok, %{"number" => "0x1"}}}, block_interval)

          {:ok, subscription}
        end)
      end

      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments)

      assert_receive {^subscription, {:ok, %{"number" => _}}}, block_interval * 2
    end
  end

  describe "unsubscribe/2" do
    # Infura timeouts on 2018-09-10
    @tag :no_geth
    test "can unsubscribe", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        subscription = %Subscription{
          reference: make_ref(),
          subscriber_pid: subscriber_pid,
          transport: transport,
          transport_options: transport_options
        }

        transport
        |> expect(:subscribe, fn _, _, _ -> {:ok, subscription} end)
        |> expect(:unsubscribe, fn ^subscription -> :ok end)
      end

      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments)

      assert :ok = EthereumJSONRPC.unsubscribe(subscription)
    end

    # Infura timeouts on 2018-09-10
    @tag :no_geth
    test "stops messages being sent to subscriber", %{
      block_interval: block_interval,
      subscribe_named_arguments: subscribe_named_arguments
    } do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        subscription = %Subscription{
          reference: make_ref(),
          subscriber_pid: subscriber_pid,
          transport: transport,
          transport_options: Keyword.fetch!(subscribe_named_arguments, :transport_options)
        }

        {:ok, pid} = Task.start_link(EthereumJSONRPC.WebSocket.Case.Mox, :loop, [%{}])

        transport
        |> expect(:subscribe, 2, fn "newHeads", [], _ ->
          send(pid, {:subscribe, subscription})

          {:ok, subscription}
        end)
        |> expect(:unsubscribe, fn ^subscription ->
          send(pid, {:unsubscribe, subscription})

          :ok
        end)
      end

      assert {:ok, first_subscription} = EthereumJSONRPC.subscribe("newHeads", [], subscribe_named_arguments)
      assert {:ok, second_subscription} = EthereumJSONRPC.subscribe("newHeads", [], subscribe_named_arguments)

      wait = block_interval * 2

      assert_receive {^first_subscription, {:ok, %{"number" => _}}}, wait
      assert_receive {^second_subscription, {:ok, %{"number" => _}}}, wait

      assert :ok = EthereumJSONRPC.unsubscribe(first_subscription)

      clear_mailbox()

      # see the message on the second subscription, so that we don't have to wait for the refute_receive, which would
      # wait the full timeout
      assert_receive {^second_subscription, {:ok, %{"number" => _}}}, wait
      refute_receive {^first_subscription, _}
    end

    test "return error if already unsubscribed", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        subscription = %Subscription{
          reference: make_ref(),
          subscriber_pid: subscriber_pid,
          transport: transport,
          transport_options: transport_options
        }

        transport
        |> expect(:subscribe, fn _, _, _ -> {:ok, subscription} end)
        |> expect(:unsubscribe, fn ^subscription -> :ok end)
        |> expect(:unsubscribe, fn ^subscription -> {:error, :not_found} end)
      end

      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", [], subscribe_named_arguments)

      assert :ok = EthereumJSONRPC.unsubscribe(subscription)

      assert {:error, :not_found} = EthereumJSONRPC.unsubscribe(subscription)
    end
  end

  describe "unique_request_id" do
    test "returns integer" do
      assert is_integer(EthereumJSONRPC.unique_request_id())
    end
  end

  describe "execute_contract_functions/3" do
    test "executes the functions with the block_number" do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      functions = [
        %{
          contract_address: "0x0000000000000000000000000000000000000000",
          data: "0x6d4ce63c",
          id: "get"
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }
           ]}
        end
      )

      blockchain_result =
        {:ok,
         [
           %{
             id: "get",
             jsonrpc: "2.0",
             result: "0x0000000000000000000000000000000000000000000000000000000000000000"
           }
         ]}

      assert EthereumJSONRPC.execute_contract_functions(
               functions,
               json_rpc_named_arguments,
               block_number: 1000
             ) == blockchain_result
    end

    test "executes the functions even when the block_number is not given" do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      functions = [
        %{
          contract_address: "0x0000000000000000000000000000000000000000",
          data: "0x6d4ce63c",
          id: "get"
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: _, params: [%{data: _, to: _}, "latest"]}], _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }
           ]}
        end
      )

      blockchain_result =
        {:ok,
         [
           %{
             id: "get",
             jsonrpc: "2.0",
             result: "0x0000000000000000000000000000000000000000000000000000000000000000"
           }
         ]}

      assert EthereumJSONRPC.execute_contract_functions(
               functions,
               json_rpc_named_arguments
             ) == blockchain_result
    end
  end

  defp clear_mailbox do
    receive do
      _ -> clear_mailbox()
    after
      0 ->
        :ok
    end
  end
end
