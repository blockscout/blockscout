defmodule Indexer.Fetcher.CeloAccountsTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox
  import Explorer.Celo.CacheHelper

  @moduletag :capture_log

  setup :verify_on_exit!
  setup :set_mox_global

  describe "run/3" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      Indexer.Fetcher.CeloAccount.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :ok
    end

    test "imports the given token balances" do
      address = <<71, 225, 114, 246, 207, 182, 199, 208, 28, 21, 116, 250, 62, 43, 231, 204, 115, 38, 157, 149>>

      get_account_data_from_blockchain()
      set_test_address()

      entry = Indexer.Fetcher.CeloAccount.entry(%{address: address}, [], [])

      assert Indexer.Fetcher.CeloAccount.run(
               [entry],
               nil
             ) == :ok

      assert {:ok,
              %Explorer.Chain.CeloAccount{
                account_type: "validator",
                address: %Explorer.Chain.Hash{
                  byte_count: 20,
                  bytes: _
                },
                name: "CLabs Validator #0 on testing",
                locked_gold: locked_gold,
                nonvoting_locked_gold: nonvoting_locked_gold,
                url: nil
              }} = Explorer.Chain.get_celo_account(address)

      assert locked_gold.value == Decimal.new(10_001_000_000_000_000_000_000)
      assert nonvoting_locked_gold.value == Decimal.new(1_000_000_000_000_000_000)
    end
  end

  def get_account_data_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      1,
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
