defmodule EthereumJSONRPCTest do
  use EthereumJSONRPC.Case, async: true

  import EthereumJSONRPC.Case
  import Mox

  alias EthereumJSONRPC.Subscription

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
                [
                  %{
                    address_hash: hash,
                    block_number: 1,
                    value: expected_fetched_balance
                  }
                ]}
    end

    test "with all invalid hash_data returns {:error, reasons}", %{json_rpc_named_arguments: json_rpc_named_arguments} do
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

      assert {:error,
              [
                %{
                  code: -32602,
                  data: %{"blockNumber" => "0x1", "hash" => "0x0"},
                  message: ^expected_message
                }
              ]} =
               EthereumJSONRPC.fetch_balances([%{block_quantity: "0x1", hash_data: "0x0"}], json_rpc_named_arguments)
    end

    test "with a mix of valid and invalid hash_data returns {:error, reasons}", %{
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

      assert {:error, reasons} =
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

      assert is_list(reasons)
      assert length(reasons) > 1
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
  end

  describe "subscribe/2" do
    test "can subscribe to newHeads", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        expect(transport, :subscribe, fn _, _, _ ->
          {:ok,
           %Subscription{
             id: "0x1",
             subscriber_pid: subscriber_pid,
             transport: transport,
             transport_options: transport_options
           }}
        end)
      end

      assert {:ok,
              %Subscription{
                id: subscription_id,
                subscriber_pid: ^subscriber_pid,
                transport: ^transport,
                transport_options: ^transport_options
              }} = EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments)

      assert is_binary(subscription_id)
    end

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
            id: "0x1",
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
    test "can unsubscribe", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        subscription = %Subscription{
          id: "0x1",
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

    test "stops messages being sent to subscriber", %{
      block_interval: block_interval,
      subscribe_named_arguments: subscribe_named_arguments
    } do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        subscription = %Subscription{
          id: "0x1",
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
          id: "0x1",
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
        fn [%{id: id, method: _, params: [%{data: _, to: _}]}], _options ->
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
