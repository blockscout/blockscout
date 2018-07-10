defmodule EthereumJSONRPC.ReceiptsTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.Receipts

  setup do
    %{variant: EthereumJSONRPC.config(:variant)}
  end

  doctest Receipts

  # These are integration tests that depend on the sokol chain being used.  sokol can be used with the following config
  #
  #     config :explorer, EthereumJSONRPC,
  #       trace_url: "https://sokol-trace.poa.network",
  #       url: "https://sokol.poa.network"
  #
  describe "fetch/1" do
    test "with receipts and logs", %{variant: variant} do
      case variant do
        EthereumJSONRPC.Geth ->
          assert {:ok,
                  %{
                    logs: [],
                    receipts: [
                      %{
                        cumulative_gas_used: 1_238_877,
                        gas_used: 21000,
                        status: :ok,
                        transaction_hash: "0x360fb62cc817093e5624468735803ea39cad719e5c68ca322bae6ba4f520756f",
                        transaction_index: 57
                      }
                    ]
                  }} =
                   Receipts.fetch([
                     %{
                       gas: 90000,
                       hash: "0x360fb62cc817093e5624468735803ea39cad719e5c68ca322bae6ba4f520756f"
                     }
                   ])

        EthereumJSONRPC.Parity ->
          assert {:ok,
                  %{
                    logs: [
                      %{
                        address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                        data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                        first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
                        fourth_topic: nil,
                        index: 0,
                        second_topic: nil,
                        third_topic: nil,
                        transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                        type: "mined"
                      }
                    ],
                    receipts: [
                      %{
                        cumulative_gas_used: 50450,
                        gas_used: 50450,
                        status: :ok,
                        transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                        transaction_index: 0
                      }
                    ]
                  }} =
                   Receipts.fetch([
                     %{
                       gas: 50451,
                       hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
                     }
                   ])

        _ ->
          raise ArgumentError, "Unsupported variant (#{variant})"
      end
    end
  end
end
