defmodule Explorer.Token.AccountReaderTest do
  use EthereumJSONRPC.Case

  alias Explorer.Celo.AccountReader

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "get_account_data" do
    test "get_account_data success" do
      get_account_data_from_blockchain()

      address = <<71, 225, 114, 246, 207, 182, 199, 208, 28, 21, 116, 250, 62, 43, 231, 204, 115, 38, 157, 149>>

      response =
        {:ok,
         %{
           account_type: "validator",
           address: address,
           locked_gold: 10_001_000_000_000_000_000_000,
           nonvoting_locked_gold: 1_000_000_000_000_000_000,
           name: "CLabs Validator #0 on testing",
           usd: 498_952_455_425_019_320_984_225_013_322_692_204_958_526_202_242,
           url: ""
         }}

      assert AccountReader.account_data(%{address: address}) == response
    end
  end

  def get_account_data_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      8,
      fn requests, _opts ->
        {:ok,
         Enum.map(requests, fn
           # locked gold
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0x30ec70f500000000000000000000000047e172f6cfb6c7d01c1574fa3e2be7cc73269d95",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x00000000000000000000000000000000000000000000021e27c1806e59a40000"
             }

           # nonvoting locked gold
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0x3f199b4000000000000000000000000047e172f6cfb6c7d01c1574fa3e2be7cc73269d95",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
             }

           # isValidator
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0xfacd743b00000000000000000000000047e172f6cfb6c7d01c1574fa3e2be7cc73269d95",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }

           # isValidatorGroup
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0x52f13a4e00000000000000000000000047e172f6cfb6c7d01c1574fa3e2be7cc73269d95",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }

           # getName
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0x5fd4b08a00000000000000000000000047e172f6cfb6c7d01c1574fa3e2be7cc73269d95",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001d434c6162732056616c696461746f72202330206f6e2074657374696e67000000"
             }

           # getMetadataURL
           %{
             id: id,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [
               %{
                 data: "0xa8ae1a3d00000000000000000000000047e172f6cfb6c7d01c1574fa3e2be7cc73269d95",
                 to: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result:
                 "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"
             }

           # registry access
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: _
               },
               "latest"
             ]
           } ->
             %{
               id: id,
               result: "0x0000000000000000000000005765cd49b3da3942ea4a4fdb6d7bf257239fe182"
             }
         end)}
      end
    )
  end
end
