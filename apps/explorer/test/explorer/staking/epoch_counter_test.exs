defmodule Explorer.Staking.ContractStateTest do
  use ExUnit.Case, async: false

  import Mox

  alias Explorer.Staking.ContractState
  alias Explorer.Chain.Events.Publisher

  setup :verify_on_exit!
  setup :set_mox_global

  test "when disabled, it returns nil" do
    assert ContractState.epoch_number() == nil
    assert ContractState.epoch_end_block() == nil
  end

  test "fetch epoch data" do
    set_mox(10, 880)
    Application.put_env(:explorer, ContractState, enabled: true)
    start_supervised!(ContractState)

    Process.sleep(1_000)

    assert ContractState.epoch_number() == 10
    assert ContractState.epoch_end_block() == 880
  end

  test "fetch new epoch data" do
    set_mox(10, 880)
    Application.put_env(:explorer, ContractState, enabled: true)
    start_supervised!(ContractState)

    Process.sleep(1_000)

    assert ContractState.epoch_number() == 10
    assert ContractState.epoch_end_block() == 880

    event_type = :blocks
    broadcast_type = :realtime
    event_data = [%Explorer.Chain.Block{number: 881}]

    set_mox(11, 960)
    Publisher.broadcast([{event_type, event_data}], broadcast_type)

    Process.sleep(1_000)

    assert ContractState.epoch_number() == 11
    assert ContractState.epoch_end_block() == 960
  end

  defp set_mox(epoch_num, end_block_num) do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [
           %{
             id: 0,
             jsonrpc: "2.0",
             method: "eth_call",
             params: _
           },
           %{
             id: 1,
             jsonrpc: "2.0",
             method: "eth_call",
             params: _
           }
         ],
         _options ->
        {:ok,
         [
           %{
             id: 0,
             jsonrpc: "2.0",
             result: encode_num(epoch_num)
           },
           %{
             id: 1,
             jsonrpc: "2.0",
             result: encode_num(end_block_num)
           }
         ]}
      end
    )
  end

  defp encode_num(num) do
    selector = %ABI.FunctionSelector{function: nil, types: [uint: 32]}

    encoded_num =
      [num]
      |> ABI.TypeEncoder.encode(selector)
      |> Base.encode16(case: :lower)

    "0x" <> encoded_num
  end
end
