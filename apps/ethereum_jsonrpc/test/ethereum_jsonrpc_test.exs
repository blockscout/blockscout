defmodule EthereumJSONRPCTest do
  use EthereumJSONRPC.Case, async: true

  import EthereumJSONRPC.Case
  import Mox

  alias EthereumJSONRPC.{Subscription, WebSocket}

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
    setup do
      pid = start_supervised!({WebSocket.Client, %{url: EthereumJSONRPC.WebSocket.Case.url()}})

      %{
        block_interval: 5000,
        json_rpc_named_arguments: [
          transport: EthereumJSONRPC.WebSocket,
          transport_options: %{
            pid: pid
          }
        ]
      }
    end

    test "can subscribe to newHeads", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      subscriber_pid = self()
      options = json_rpc_named_arguments[:transport_options]

      assert {:ok,
              %Subscription{
                id: subscription_id,
                subscriber_pid: ^subscriber_pid,
                transport: WebSocket,
                transport_options: ^options
              }} = EthereumJSONRPC.subscribe("newHeads", json_rpc_named_arguments)

      assert is_binary(subscription_id)
    end

    test "delivers new heads to caller", %{block_interval: block_interval, json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", json_rpc_named_arguments)

      assert_receive {^subscription, {:ok, %{"number" => _}}}, block_interval * 2
    end
  end

  describe "unsubscribe/2" do
    setup do
      pid = start_supervised!({WebSocket.Client, %{url: EthereumJSONRPC.WebSocket.Case.url()}})

      %{
        block_interval: 5000,
        json_rpc_named_arguments: [
          transport: EthereumJSONRPC.WebSocket,
          transport_options: %{
            pid: pid
          }
        ]
      }
    end

    test "can unsubscribe", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", json_rpc_named_arguments)

      assert {:ok, true} = EthereumJSONRPC.unsubscribe(subscription)
    end

    test "stops messages being sent to subscriber", %{
      block_interval: block_interval,
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", json_rpc_named_arguments)

      wait = block_interval * 2

      assert_receive {^subscription, {:ok, %{"number" => _}}}, wait

      assert {:ok, true} = EthereumJSONRPC.unsubscribe(subscription)

      clear_mailbox()

      refute_receive {^subscription, _}, wait
    end

    test "return error if already unsubscribed", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", [], json_rpc_named_arguments)
      assert {:ok, true} = EthereumJSONRPC.unsubscribe(subscription)

      assert {:error, :not_found} = EthereumJSONRPC.unsubscribe(subscription)
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
