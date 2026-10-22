# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Address.CountersTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address.Counters

  describe "check_if_logs_at_address/2" do
    test "detects logs of the address" do
      address_with_logs = insert(:address)
      address_without_logs = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:log,
        block: transaction.block,
        block_number: transaction.block_number,
        transaction: transaction,
        address: address_with_logs
      )

      assert Counters.check_if_logs_at_address(address_with_logs.hash)
      refute Counters.check_if_logs_at_address(address_without_logs.hash)
    end
  end

  describe "address_existence_checks/2" do
    test "returns the existence checks" do
      address = insert(:address)
      insert(:block, miner: address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:log,
        block: transaction.block,
        block_number: transaction.block_number,
        transaction: transaction,
        address: address
      )

      assert %{
               has_validated_blocks: true,
               has_logs: true,
               has_tokens: false,
               has_token_transfers: false,
               has_beacon_chain_withdrawals: false
             } = Counters.address_existence_checks(address.hash, api?: true)
    end

    test "degrades `has_logs` to false instead of hanging while the logs table is locked" do
      address = insert(:address)
      insert(:block, miner: address)

      with_table_locked("logs", fn ->
        assert %{
                 has_validated_blocks: true,
                 has_logs: false,
                 has_tokens: false,
                 has_token_transfers: false,
                 has_beacon_chain_withdrawals: false
               } = Counters.address_existence_checks(address.hash, api?: true)
      end)
    end

    test "reports every check as false instead of hanging while another checked table is locked" do
      address = insert(:address)

      with_table_locked("token_transfers", fn ->
        assert %{
                 has_validated_blocks: false,
                 has_logs: false,
                 has_tokens: false,
                 has_token_transfers: false,
                 has_beacon_chain_withdrawals: false
               } = Counters.address_existence_checks(address.hash, api?: true)
      end)
    end
  end

  describe "address_limited_counters/2" do
    test "counts logs of the address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      log_params = [
        block: transaction.block,
        block_number: transaction.block_number,
        transaction: transaction,
        address: address
      ]

      insert(:log, log_params ++ [index: 1])
      insert(:log, log_params ++ [index: 2])
      insert(:log, log_params ++ [index: 3])
      # log of another address
      insert(:log, log_params ++ [index: 4, address: insert(:address)])

      assert %{logs: 3} = Counters.address_limited_counters(address.hash, [])
    end
  end
end
