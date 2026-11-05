# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Migrator.RecoveryWETHTokenTransfersTest do
  use Explorer.DataCase, async: false

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.Chain.{Log, TokenTransfer}
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Repo

  alias Indexer.Migrator.RecoveryWETHTokenTransfers

  describe "RecoveryWETHTokenTransfers" do
    test "recovery WETH token transfers" do
      %{contract_address: token_address} = insert(:token, type: "ERC-20")

      address_1 = insert(:address)
      block_1 = insert(:block)
      transaction_1 = insert(:transaction) |> with_block(block_1)

      log_1 =
        insert(:withdrawal_log,
          from_address: address_1,
          token_contract_address: token_address,
          amount: 1000,
          transaction: transaction_1,
          block: block_1
        )

      log_2 =
        insert(:withdrawal_log,
          from_address: address_1,
          token_contract_address: token_address,
          amount: 1000,
          transaction: transaction_1,
          block: block_1
        )

      transaction_random = insert(:transaction) |> with_block(block_1)

      # shouldn't be inserted
      log_random_1 =
        insert(:withdrawal_log,
          from_address: address_1,
          token_contract_address: token_address,
          amount: 1001,
          transaction: transaction_random,
          block: block_1
        )

      insert(:token_transfer,
        from_address_hash: burn_address_hash_string(),
        from_address: nil,
        to_address: address_1,
        token_contract_address: token_address,
        block: block_1,
        transaction: transaction_random,
        log_index: log_random_1.index
      )

      # shouldn't be inserted
      log_random_2 =
        insert(:withdrawal_log,
          from_address: address_1,
          token_contract_address: token_address,
          amount: 1002,
          transaction: transaction_random,
          block: block_1
        )

      insert(:token_transfer,
        from_address_hash: burn_address_hash_string(),
        from_address: nil,
        to_address: address_1,
        token_contract_address: token_address,
        block: block_1,
        transaction: transaction_random,
        log_index: log_random_2.index
      )

      block_2 = insert(:block)
      transaction_2 = insert(:transaction) |> with_block(block_2)

      _log_3 =
        insert(:withdrawal_log,
          from_address: address_1,
          token_contract_address: token_address,
          amount: 10023,
          transaction: transaction_2,
          block: block_2
        )

      _log_4 =
        insert(:deposit_log,
          from_address: address_1,
          token_contract_address: token_address,
          amount: 10023,
          transaction: transaction_2,
          block: block_2
        )

      address_3 = insert(:address)
      block_3 = insert(:block)
      transaction_3 = insert(:transaction) |> with_block(block_3)

      log_5 =
        insert(:deposit_log,
          from_address: address_3,
          token_contract_address: token_address,
          amount: 1000,
          transaction: transaction_3,
          block: block_3
        )

      log_6 =
        insert(:deposit_log,
          from_address: address_3,
          token_contract_address: token_address,
          amount: 1000,
          transaction: transaction_3,
          block: block_3
        )

      _tt_6 =
        insert(:token_transfer,
          from_address_hash: burn_address_hash_string(),
          from_address: nil,
          to_address: address_3,
          token_contract_address: token_address,
          block: log_6.block,
          transaction: log_6.transaction,
          log_index: log_6.index
        )

      assert MigrationStatus.get_status("recovery_weth_token_transfers") == nil
      envs = Application.get_env(:indexer, Indexer.Migrator.RecoveryWETHTokenTransfers)
      envs_tt = Application.get_env(:explorer, Explorer.Chain.TokenTransfer)

      Application.put_env(
        :explorer,
        Explorer.Chain.TokenTransfer,
        Keyword.merge(envs, weth_token_transfers_filtering_enabled: false)
      )

      Application.put_env(
        :indexer,
        Indexer.Migrator.RecoveryWETHTokenTransfers,
        Keyword.merge(envs, batch_size: 1, concurrency: 2, blocks_batch_size: 1)
      )

      RecoveryWETHTokenTransfers.start_link([])
      Process.sleep(1000)

      assert MigrationStatus.get_status("recovery_weth_token_transfers") == "completed"

      assert [tt_1, tt_2, _tt_3, _tt_4, tt_5, _tt_6] = Repo.all(TokenTransfer |> order_by([tt], asc: tt.log_index))
      check_withdrawal_token_transfer(tt_1, log_1)
      check_withdrawal_token_transfer(tt_2, log_2)
      check_deposit_token_transfer(tt_5, log_5)

      Application.put_env(:indexer, Indexer.Migrator.RecoveryWETHTokenTransfers, envs)
      Application.put_env(:explorer, Explorer.Chain.TokenTransfer, envs_tt)
    end

    test "recovers WETH token transfers from logs stored in the optimized format" do
      # logs without `first_topic` are found by `first_topic_id` only once the migration is started
      set_fill_logs_optimized_fields_migration_started()

      %{contract_address: token_address} = insert(:token, type: "ERC-20")

      address = insert(:address)
      block = insert(:block)
      transaction = insert(:transaction) |> with_block(block)

      log_params = [
        from_address: address,
        token_contract_address: token_address,
        amount: 1000,
        transaction: transaction,
        block: block
      ]

      log_1 = insert(:withdrawal_log, log_params)
      log_2 = insert(:withdrawal_log, log_params)

      Enum.each([log_1, log_2], &store_in_optimized_format/1)

      envs = Application.get_env(:indexer, RecoveryWETHTokenTransfers)
      envs_tt = Application.get_env(:explorer, TokenTransfer)

      Application.put_env(
        :explorer,
        TokenTransfer,
        Keyword.merge(envs_tt,
          weth_token_transfers_filtering_enabled: true,
          whitelisted_weth_contracts: [token_address.hash |> to_string() |> String.downcase()]
        )
      )

      Application.put_env(
        :indexer,
        RecoveryWETHTokenTransfers,
        Keyword.merge(envs, batch_size: 1, concurrency: 2, blocks_batch_size: 1, timeout: 0)
      )

      on_exit(fn ->
        Application.put_env(:indexer, RecoveryWETHTokenTransfers, envs)
        Application.put_env(:explorer, TokenTransfer, envs_tt)
      end)

      {:ok, pid} = RecoveryWETHTokenTransfers.start_link([])
      ref = Process.monitor(pid)

      # the migrator stops itself once the migration is completed
      assert_receive {:DOWN, ^ref, :process, ^pid, reason} when reason in [:normal, :noproc], 5_000

      assert MigrationStatus.get_status("recovery_weth_token_transfers") == "completed"

      assert [tt_1, tt_2] = Repo.all(TokenTransfer |> order_by([tt], asc: tt.log_index))
      check_withdrawal_token_transfer(tt_1, log_1)
      check_withdrawal_token_transfer(tt_2, log_2)
    end
  end

  # Emulates a log imported by v12+ or processed by the `fill_logs_optimized_fields`
  # and `fill_logs_compressed_data` migrations: `address_hash`, `first_topic` and
  # `data` are kept only in `address_id`, `first_topic_id` and `compressed_data`.
  defp store_in_optimized_format(log) do
    {1, _} =
      Log
      |> where([l], l.block_number == ^log.block_number and l.index == ^log.index)
      |> Repo.update_all(set: [address_hash: nil, first_topic: nil, data: nil, compressed_data: log.data])
  end

  def check_withdrawal_token_transfer(tt, log) do
    {amount, _} = log.data |> to_string() |> String.trim_leading("0x") |> Integer.parse(16)

    assert Decimal.to_integer(tt.amount) == amount
    assert to_string(tt.from_address_hash) == "0x" <> (log.second_topic |> to_string() |> String.slice(-40, 40))
    assert to_string(tt.to_address_hash) == burn_address_hash_string()
    assert tt.token_contract_address_hash == log.address_hash
  end

  def check_deposit_token_transfer(tt, log) do
    {amount, _} = log.data |> to_string() |> String.trim_leading("0x") |> Integer.parse(16)

    assert Decimal.to_integer(tt.amount) == amount
    assert to_string(tt.to_address_hash) == "0x" <> (log.second_topic |> to_string() |> String.slice(-40, 40))
    assert to_string(tt.from_address_hash) == burn_address_hash_string()
    assert tt.token_contract_address_hash == log.address_hash
  end
end
