defmodule Explorer.Staking.ContractStateTest do
  use ExUnit.Case, async: false

  import Mox

  alias Explorer.Staking.ContractState
  alias Explorer.Chain.Events.Publisher

  setup :verify_on_exit!
  setup :set_mox_global

  @contract_a <<16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
  @contract_b <<24, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>

  test "when disabled, returns default values" do
    assert ContractState.epoch_number() == 0
    assert ContractState.epoch_end_block() == 0
    assert ContractState.min_delegator_stake() == 1
    assert ContractState.min_candidate_stake() == 1
    assert ContractState.token_contract_address() == nil
  end

  test "fetch epoch data" do
    set_mox(%{
      epoch_num: 10,
      end_block_num: 880,
      min_delegator_stake: 1,
      min_candidate_stake: 2,
      token_contract_address: @contract_a
    })

    Application.put_env(:explorer, ContractState, enabled: true)
    start_supervised!(ContractState)

    Process.sleep(1_000)

    assert ContractState.epoch_number() == 10
    assert ContractState.epoch_end_block() == 880
    assert ContractState.min_delegator_stake() == 1
    assert ContractState.min_candidate_stake() == 2
    assert ContractState.token_contract_address() == @contract_a
  end

  test "fetch new epoch data" do
    set_mox(%{
      epoch_num: 10,
      end_block_num: 880,
      min_delegator_stake: 1,
      min_candidate_stake: 2,
      token_contract_address: @contract_a
    })

    Application.put_env(:explorer, ContractState, enabled: true)
    start_supervised!(ContractState)

    Process.sleep(1_000)

    assert ContractState.epoch_number() == 10
    assert ContractState.epoch_end_block() == 880
    assert ContractState.min_delegator_stake() == 1
    assert ContractState.min_candidate_stake() == 2
    assert ContractState.token_contract_address() == @contract_a

    event_type = :blocks
    broadcast_type = :realtime
    event_data = [%Explorer.Chain.Block{number: 881}]

    set_mox(%{
      epoch_num: 11,
      end_block_num: 960,
      min_delegator_stake: 3,
      min_candidate_stake: 4,
      token_contract_address: @contract_b
    })

    Publisher.broadcast([{event_type, event_data}], broadcast_type)

    Process.sleep(1_000)

    assert ContractState.epoch_number() == 11
    assert ContractState.epoch_end_block() == 960
    assert ContractState.min_delegator_stake() == 3
    assert ContractState.min_candidate_stake() == 4
    assert ContractState.token_contract_address() == @contract_b
  end

  defp set_mox(%{
         epoch_num: epoch_num,
         end_block_num: end_block_num,
         min_delegator_stake: min_delegator_stake,
         min_candidate_stake: min_candidate_stake,
         token_contract_address: token_contract_address
       }) do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn
        [
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
          },
          %{
            id: 2,
            jsonrpc: "2.0",
            method: "eth_call",
            params: _
          },
          %{
            id: 3,
            jsonrpc: "2.0",
            method: "eth_call",
            params: _
          },
          %{
            id: 4,
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
             },
             %{
               id: 2,
               jsonrpc: "2.0",
               result: encode_num(min_delegator_stake)
             },
             %{
               id: 3,
               jsonrpc: "2.0",
               result: encode_num(min_candidate_stake)
             },
             %{
               id: 4,
               jsonrpc: "2.0",
               result: encode_address(token_contract_address)
             }
           ]}
      end
    )
  end

  defp encode_address(addr) do
    encode([:address], addr)
  end

  defp encode_num(num) do
    encode([uint: 32], num)
  end

  defp encode(ty, value) do
    selector = %ABI.FunctionSelector{function: nil, types: ty}

    encoded_value =
      [value]
      |> ABI.TypeEncoder.encode(selector)
      |> Base.encode16(case: :lower)

    "0x" <> encoded_value
  end
end
