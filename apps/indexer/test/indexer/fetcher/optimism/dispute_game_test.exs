if Application.get_env(:explorer, :chain_type) == :optimism do
  defmodule Indexer.Fetcher.Optimism.DisputeGameTest do
    use EthereumJSONRPC.Case, async: false
    use Explorer.DataCase

    import Mox

    alias Explorer.Chain.Data
    alias Indexer.Fetcher.Optimism.DisputeGame

    setup :verify_on_exit!

    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
    end

    describe "handle_info/2" do
      defp mox_handle_continue_calls(%{
             id: id,
             method: "eth_call",
             params: [
               %{data: data, to: _},
               _
             ]
           })
           when data in ~w(0x3c9f397c 0x19effeb4 0x200d2ed2),
           do: %{id: id, jsonrpc: "2.0", result: "0x0"}

      defp mox_handle_continue_calls(%{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: %Data{bytes: <<187, 138, 161, 252, index::integer-256>>},
                 to: "0x3078000000000000000000000000000000000001"
               },
               _
             ]
           }) do
        %{
          id: id,
          jsonrpc: "2.0",
          result:
            "0x" <>
              (ABI.encode("(uint32,uint64,address)", [
                 {1, index + 1_740_000_000, 0x3078A00000000000000000000000000000000000 + index}
               ])
               |> Base.encode16(case: :lower))
        }
      end

      defp mox_handle_continue_calls(%{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x609d3334", to: "0x3078a0000000000000000000000000000000000" <> index},
               _
             ]
           }) do
        {index, ""} = Integer.parse(index)

        %{
          id: id,
          jsonrpc: "2.0",
          result:
            "0x" <>
              (ABI.TypeEncoder.encode([4, <<46 + index, 120, 32, 32 + index>>], [:bytes])
               |> Base.encode16(case: :lower))
        }
      end

      defp mox_handle_continue_calls(%{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0x609d3334",
                 to: %Explorer.Chain.Hash{
                   byte_count: 20,
                   bytes: <<48, 120, 160, 0::128, index>>
                 }
               },
               _
             ]
           }) do
        %{
          id: id,
          jsonrpc: "2.0",
          result:
            "0x" <>
              (ABI.TypeEncoder.encode([<<46 + index, 120, 32, 32 + index>>], [:bytes]) |> Base.encode16(case: :lower))
        }
      end

      defp mox_handle_continue_calls(%{
             id: id,
             method: "eth_call",
             params: [
               %{data: "0x4d1975b4", to: _},
               _
             ]
           }) do
        %{id: id, jsonrpc: "2.0", result: "0x5"}
      end

      test "handles :continue", %{json_rpc_named_arguments: json_rpc_named_arguments} do
        old_env = Application.get_env(:indexer, DisputeGame, [])

        Application.put_env(
          :indexer,
          DisputeGame,
          Keyword.merge(old_env, json_rpc_named_arguments: json_rpc_named_arguments)
        )

        on_exit(fn ->
          Application.put_env(:indexer, DisputeGame, old_env)
        end)

        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          8,
          fn
            requests, _options when is_list(requests) ->
              {:ok, Enum.map(requests, &mox_handle_continue_calls/1)}

            request, _options ->
              {:ok, mox_handle_continue_calls(request).result}
          end
        )

        assert {:noreply,
                %{
                  optimism_portal: "0x3078000000000000000000000000000000000002",
                  dispute_game_factory: "0x3078000000000000000000000000000000000001",
                  end_index: 4,
                  start_index: 4
                }} =
                 DisputeGame.handle_info(:continue, %{
                   dispute_game_factory: "0x3078000000000000000000000000000000000001",
                   optimism_portal: "0x3078000000000000000000000000000000000002",
                   start_index: 0,
                   end_index: 3,
                   json_rpc_named_arguments: json_rpc_named_arguments
                 })

        assert [
                 %Explorer.Chain.Optimism.DisputeGame{
                   index: 0,
                   game_type: 1,
                   address_hash: %Explorer.Chain.Hash{
                     byte_count: 20,
                     bytes: <<48, 120, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
                   },
                   extra_data: %Explorer.Chain.Data{bytes: ".x  "},
                   resolved_at: nil,
                   status: 0
                 },
                 %Explorer.Chain.Optimism.DisputeGame{
                   index: 1,
                   game_type: 1,
                   address_hash: %Explorer.Chain.Hash{
                     byte_count: 20,
                     bytes: <<48, 120, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
                   },
                   extra_data: %Explorer.Chain.Data{bytes: "/x !"},
                   resolved_at: nil,
                   status: 0
                 },
                 %Explorer.Chain.Optimism.DisputeGame{
                   index: 2,
                   game_type: 1,
                   address_hash: %Explorer.Chain.Hash{
                     byte_count: 20,
                     bytes: <<48, 120, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
                   },
                   extra_data: %Explorer.Chain.Data{bytes: "0x \""},
                   resolved_at: nil,
                   status: 0
                 },
                 %Explorer.Chain.Optimism.DisputeGame{
                   index: 3,
                   game_type: 1,
                   address_hash: %Explorer.Chain.Hash{
                     byte_count: 20,
                     bytes: <<48, 120, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3>>
                   },
                   extra_data: %Explorer.Chain.Data{bytes: "1x #"},
                   resolved_at: nil,
                   status: 0
                 }
               ] = Repo.all(Explorer.Chain.Optimism.DisputeGame)
      end
    end
  end
end
