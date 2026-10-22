# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Beacon.DepositTest do
  use Explorer.DataCase

  alias Explorer.Chain.Beacon.Deposit
  alias Explorer.Chain.Hash

  @deposit_event_signature "0x649BBC62D0E31342AFEA4E5CD82D4049E7E1EE912FC0889AA790803BE39038C5"

  describe "get_logs_with_deposits/4" do
    test "fetches deposit logs of the deposit contract" do
      deposit_contract_address = insert(:address)
      {:ok, first_topic} = Hash.Full.cast(@deposit_event_signature)

      transaction =
        :transaction
        |> insert(to_address: deposit_contract_address)
        |> with_block()

      log_params = [
        block: transaction.block,
        block_number: transaction.block_number,
        transaction: transaction,
        address: deposit_contract_address,
        first_topic: first_topic
      ]

      %{data: first_log_data} = insert(:log, log_params ++ [index: 1])
      %{data: second_log_data} = insert(:log, log_params ++ [index: 2])
      # log of another address
      insert(:log, log_params ++ [index: 3, address: insert(:address)])
      # log with another first topic
      insert(:log, log_params ++ [index: 4, first_topic: nil])

      logs = Deposit.get_logs_with_deposits(deposit_contract_address.hash, transaction.block_number - 1, 0, 10)

      assert [%{index: 1, data: ^first_log_data}, %{index: 2, data: ^second_log_data}] = logs

      assert Enum.all?(logs, fn log ->
               log.block_number == transaction.block_number and log.block_hash == transaction.block_hash and
                 log.transaction_hash == transaction.hash and log.from_address_hash == transaction.from_address_hash and
                 log.first_topic == first_topic
             end)
    end

    test "respects the limit and the paging key" do
      deposit_contract_address = insert(:address)
      {:ok, first_topic} = Hash.Full.cast(@deposit_event_signature)

      transaction =
        :transaction
        |> insert(to_address: deposit_contract_address)
        |> with_block()

      log_params = [
        block: transaction.block,
        block_number: transaction.block_number,
        transaction: transaction,
        address: deposit_contract_address,
        first_topic: first_topic
      ]

      insert(:log, log_params ++ [index: 1])
      insert(:log, log_params ++ [index: 2])
      insert(:log, log_params ++ [index: 3])

      assert [1] ==
               deposit_contract_address.hash
               |> Deposit.get_logs_with_deposits(transaction.block_number - 1, 0, 1)
               |> Enum.map(& &1.index)

      assert [2, 3] ==
               deposit_contract_address.hash
               |> Deposit.get_logs_with_deposits(transaction.block_number, 1, 10)
               |> Enum.map(& &1.index)
    end
  end
end
