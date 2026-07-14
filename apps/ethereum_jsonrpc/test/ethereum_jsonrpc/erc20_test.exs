# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.ERC20Test do
  use ExUnit.Case, async: true

  import Mox

  alias EthereumJSONRPC.ERC20

  setup :verify_on_exit!

  setup do
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.Mox,
        transport_options: []
      ]
    }
  end

  describe "fetch_token_properties/3" do
    test "decodes standard string name and symbol", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      token_address = "0xdac17f958d2ee523a2206206994597c13d831ec7"

      expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
        {:ok,
         Enum.map(requests, fn
           %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: ^token_address}, "latest"]} ->
             %{id: id, result: "0x0000000000000000000000000000000000000000000000000000000000000006"}

           %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: ^token_address}, "latest"]} ->
             %{id: id, result: abi_encoded_string("Tether USD")}

           %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: ^token_address}, "latest"]} ->
             %{id: id, result: abi_encoded_string("USDT")}
         end)}
      end)

      assert ERC20.fetch_token_properties(
               token_address,
               [:decimals, :name, :symbol],
               json_rpc_named_arguments
             ) == %{
               decimals: 6,
               name: "Tether USD",
               symbol: "USDT"
             }
    end

    test "falls back to bytes32 name and symbol", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      token_address = "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"

      expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
        {:ok,
         Enum.map(requests, fn
           %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: ^token_address}, "latest"]} ->
             %{id: id, result: "0x0000000000000000000000000000000000000000000000000000000000000012"}

           %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: ^token_address}, "latest"]} ->
             %{
               id: id,
               result: "0x4d616b6572000000000000000000000000000000000000000000000000000000"
             }

           %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: ^token_address}, "latest"]} ->
             %{
               id: id,
               result: "0x4d4b520000000000000000000000000000000000000000000000000000000000"
             }
         end)}
      end)

      assert ERC20.fetch_token_properties(
               token_address,
               [:decimals, :name, :symbol],
               json_rpc_named_arguments
             ) == %{
               decimals: 18,
               name: "Maker",
               symbol: "MKR"
             }
    end
  end

  defp abi_encoded_string(str) do
    encoded =
      ABI.TypeEncoder.encode([str], %ABI.FunctionSelector{
        function: nil,
        types: [:string]
      })

    "0x" <> Base.encode16(encoded, case: :lower)
  end
end
