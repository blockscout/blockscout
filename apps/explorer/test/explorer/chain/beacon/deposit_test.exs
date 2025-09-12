defmodule Explorer.Chain.Beacon.DepositTest do
  use Explorer.DataCase

  alias Explorer.Chain.Beacon.Deposit

  describe "get_logs_with_deposits/4" do
    @deposit_event_signature "0x649BBC62D0E31342AFEA4E5CD82D4049E7E1EE912FC0889AA790803BE39038C5"

    test "filter out reorged blocks" do
      deposit_contract = insert(:address)
      reorg = insert(:block, consensus: false)
      actual_block = insert(:block, consensus: true, number: reorg.number)
      transaction = insert(:transaction) |> with_block(actual_block)

      reorged_logs = [
        insert(:log,
          address: deposit_contract,
          block: reorg,
          transaction: transaction,
          first_topic: @deposit_event_signature
        ),
        insert(:log,
          address: deposit_contract,
          block: reorg,
          transaction: transaction,
          first_topic: @deposit_event_signature
        )
      ]

      actual_logs = [
        insert(:log,
          address: deposit_contract,
          block: actual_block,
          transaction: transaction,
          first_topic: @deposit_event_signature
        ),
        insert(:log,
          address: deposit_contract,
          block: actual_block,
          transaction: transaction,
          first_topic: @deposit_event_signature
        )
      ]

      assert actual_logs |> Enum.map(&{&1.transaction_hash, &1.block_hash, &1.block_number, &1.data, &1.index}) ==
               Deposit.get_logs_with_deposits(
                 deposit_contract.hash,
                 -1,
                 -1,
                 10
               )
               |> Enum.map(&{&1.transaction_hash, &1.block_hash, &1.block_number, &1.data, &1.index})
    end
  end
end
