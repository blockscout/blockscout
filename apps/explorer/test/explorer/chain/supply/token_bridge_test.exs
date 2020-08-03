defmodule Explorer.Chain.Supply.TokenBridgeTest do
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias Explorer.Chain.Supply.TokenBridge

  @moduletag :capture_log

  setup :set_mox_global

  setup :verify_on_exit!

  describe "total_coins/1" do
    @tag :no_parity
    @tag :no_geth
    # Flaky test
    # test "calculates total coins", %{json_rpc_named_arguments: json_rpc_named_arguments} do
    #   if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
    #     EthereumJSONRPC.Mox
    #     |> expect(:json_rpc, fn [
    #                               %{
    #                                 id: id,
    #                                 method: "eth_call",
    #                                 params: [
    #                                   %{data: "0x553a5c85", to: "0x867305d19606aadba405ce534e303d0e225f9556"},
    #                                   "latest"
    #                                 ]
    #                               }
    #                             ],
    #                             _options ->
    #       {:ok,
    #        [
    #          %{
    #            id: id,
    #            jsonrpc: "2.0",
    #            result: "0x00000000000000000000000000000000000000000000042aa8fe57ebb112dcc8"
    #          }
    #        ]}
    #     end)
    #     |> expect(:json_rpc, fn [
    #                               %{
    #                                 id: id,
    #                                 jsonrpc: "2.0",
    #                                 method: "eth_call",
    #                                 params: [
    #                                   %{data: "0x0e8162ba", to: "0x7301CFA0e1756B71869E93d4e4Dca5c7d0eb0AA6"},
    #                                   "latest"
    #                                 ]
    #                               }
    #                             ],
    #                             _options ->
    #       {:ok,
    #        [
    #          %{
    #            id: id,
    #            jsonrpc: "2.0",
    #            result: "0x00000000000000000000000000000000000000000000033cc192839185166fc6"
    #          }
    #        ]}
    #     end)
    #   end

    #   assert Decimal.round(TokenBridge.total_coins(), 2, :down) == Decimal.from_float(4388.55)
    # end
  end
end
