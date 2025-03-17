defmodule Indexer.Migrator.RecoveryWETHTokenTransfersTest do
  use Explorer.DataCase, async: false

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.Chain.TokenTransfer
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
