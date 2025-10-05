defmodule Explorer.Migrator.SanitizeIncorrectWETHTokenTransfersTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.TokenTransfer
  alias Explorer.Migrator.{SanitizeIncorrectWETHTokenTransfers, MigrationStatus}
  alias Explorer.Repo

  setup [
    :setup_explorer_chain_token_transfer_env,
    :setup_explorer_migrator_sanitize_incorrect_weth_token_transfers_env,
    :setup_common_tokens_and_addresses
  ]

  @moduletag [capture_log: true]

  describe "SanitizeIncorrectWETHTokenTransfers all at once" do
    test "Deletes not whitelisted WETH transfers and duplicated WETH transfers", %{
      token_address: token_address,
      burn_address: burn_address
    } do
      block = insert(:block, consensus: true)

      insert(:token_transfer,
        from_address: insert(:address),
        block: block,
        block_number: block.number,
        token_contract_address: token_address,
        token_ids: nil
      )

      deposit_log = insert(:log, first_topic: TokenTransfer.weth_deposit_signature())

      insert(:token_transfer,
        from_address: insert(:address),
        token_contract_address: token_address,
        block: deposit_log.block,
        transaction: deposit_log.transaction,
        log_index: deposit_log.index
      )

      withdrawal_log = insert(:log, first_topic: TokenTransfer.weth_withdrawal_signature())

      insert(:token_transfer,
        from_address: insert(:address),
        token_contract_address: token_address,
        block: withdrawal_log.block,
        transaction: withdrawal_log.transaction,
        log_index: withdrawal_log.index
      )

      %{contract_address: whitelisted_token_address} = insert(:token, type: "ERC-20")

      env = Application.get_env(:explorer, Explorer.Chain.TokenTransfer)

      Application.put_env(
        :explorer,
        Explorer.Chain.TokenTransfer,
        env
        |> Keyword.put(:whitelisted_weth_contracts, [whitelisted_token_address |> to_string() |> String.downcase()])
        |> Keyword.put(:weth_token_transfers_filtering_enabled, true)
      )

      withdrawal_log = insert(:log, first_topic: TokenTransfer.weth_withdrawal_signature())

      insert(:token_transfer,
        from_address: insert(:address),
        token_contract_address: whitelisted_token_address,
        block: withdrawal_log.block,
        transaction: withdrawal_log.transaction,
        log_index: withdrawal_log.index
      )

      deposit_log = insert(:log, first_topic: TokenTransfer.weth_deposit_signature())

      insert(:token_transfer,
        from_address: insert(:address),
        token_contract_address: whitelisted_token_address,
        block: deposit_log.block,
        transaction: deposit_log.transaction,
        log_index: deposit_log.index
      )

      withdrawal_log_duplicate =
        insert(:log, first_topic: TokenTransfer.weth_withdrawal_signature(), address: whitelisted_token_address)

      tt_withdrawal =
        insert(:token_transfer,
          from_address: burn_address,
          token_contract_address: whitelisted_token_address,
          block: withdrawal_log_duplicate.block,
          transaction: withdrawal_log_duplicate.transaction,
          log_index: withdrawal_log_duplicate.index
        )

      withdrawal_log_duplicate_original =
        insert(:log,
          first_topic: TokenTransfer.constant(),
          address: whitelisted_token_address,
          transaction: withdrawal_log_duplicate.transaction,
          block: withdrawal_log_duplicate.block
        )

      insert(:token_transfer,
        from_address: burn_address,
        to_address: tt_withdrawal.to_address,
        token_contract_address: whitelisted_token_address,
        block: withdrawal_log_duplicate_original.block,
        transaction: withdrawal_log_duplicate_original.transaction,
        log_index: withdrawal_log_duplicate_original.index,
        amount: tt_withdrawal.amount
      )

      deposit_log_duplicate = insert(:log, first_topic: TokenTransfer.weth_deposit_signature())

      tt_deposit =
        insert(:token_transfer,
          to_address: burn_address,
          token_contract_address: whitelisted_token_address,
          block: deposit_log_duplicate.block,
          transaction: deposit_log_duplicate.transaction,
          log_index: deposit_log_duplicate.index
        )

      deposit_log_duplicate_original =
        insert(:log,
          first_topic: TokenTransfer.constant(),
          address: whitelisted_token_address,
          transaction: deposit_log_duplicate.transaction,
          block: deposit_log_duplicate.block
        )

      insert(:token_transfer,
        from_address: tt_deposit.from_address,
        to_address: burn_address,
        token_contract_address: whitelisted_token_address,
        block: deposit_log_duplicate_original.block,
        transaction: deposit_log_duplicate_original.transaction,
        log_index: deposit_log_duplicate_original.index,
        amount: tt_deposit.amount
      )

      assert MigrationStatus.get_status("sanitize_incorrect_weth_transfers") == nil

      SanitizeIncorrectWETHTokenTransfers.start_link([])
      Process.sleep(100)

      assert MigrationStatus.get_status("sanitize_incorrect_weth_transfers") == "completed"

      token_address_hash = token_address.hash
      whitelisted_token_address_hash = whitelisted_token_address.hash

      assert [
               %{token_contract_address_hash: ^token_address_hash},
               %{token_contract_address_hash: ^whitelisted_token_address_hash},
               %{token_contract_address_hash: ^whitelisted_token_address_hash},
               %{token_contract_address_hash: ^whitelisted_token_address_hash},
               %{token_contract_address_hash: ^whitelisted_token_address_hash}
             ] = transfers = Repo.all(TokenTransfer, order_by: [asc: :block_number, asc: :log_index])

      withdrawal = Enum.at(transfers, 1)
      deposit = Enum.at(transfers, 2)
      assert withdrawal.block_hash == withdrawal_log.block_hash
      assert withdrawal.transaction_hash == withdrawal_log.transaction_hash
      assert withdrawal.log_index == withdrawal_log.index

      assert deposit.block_hash == deposit_log.block_hash
      assert deposit.transaction_hash == deposit_log.transaction_hash
      assert deposit.log_index == deposit_log.index

      withdrawal_analogue = Enum.at(transfers, 3)
      deposit_analogue = Enum.at(transfers, 4)

      assert withdrawal_analogue.block_hash == withdrawal_log_duplicate.block_hash
      assert withdrawal_analogue.transaction_hash == withdrawal_log_duplicate.transaction_hash
      assert withdrawal_analogue.log_index == withdrawal_log_duplicate_original.index

      assert deposit_analogue.block_hash == deposit_log_duplicate.block_hash
      assert deposit_analogue.transaction_hash == deposit_log_duplicate.transaction_hash
      assert deposit_analogue.log_index == deposit_log_duplicate_original.index
    end
  end

  describe "SanitizeIncorrectWETHTokenTransfers deletes duplicated values" do
    test "Deletes duplicated WETH deposits", %{token_address: token_address, burn_address: burn_address} do
      %{log: deposit_log, token_transfer: deposit_token_transfer} =
        insert_original_log_and_token_transfer(:deposit, token_address, burn_address)

      %{log: transfer_log, token_transfer: _transfer_token_transfer} =
        insert_duplicated_log_and_token_transfer(:transfer, deposit_log, deposit_token_transfer)

      assert MigrationStatus.get_status("sanitize_incorrect_weth_transfers") == nil
      SanitizeIncorrectWETHTokenTransfers.start_link([])
      wait_for_migration_status_updated("wait_for_enabling_weth_filtering")

      # Only token transfer corresponding to transfer log should remain. Deposit related token transfer is removed.

      token_address_hash = token_address.hash
      transfer_log_index = transfer_log.index

      assert [
               %{token_contract_address_hash: ^token_address_hash, log_index: ^transfer_log_index}
             ] = Repo.all(TokenTransfer, order_by: [asc: :block_number, asc: :log_index])
    end

    test "Deletes duplicated WETH withdrawals", %{token_address: token_address, burn_address: burn_address} do
      %{log: withdrawal_log, token_transfer: withdrawal_token_transfer} =
        insert_original_log_and_token_transfer(:withdrawal, token_address, burn_address)

      %{log: transfer_log, token_transfer: _transfer_token_transfer} =
        insert_duplicated_log_and_token_transfer(:transfer, withdrawal_log, withdrawal_token_transfer)

      assert MigrationStatus.get_status("sanitize_incorrect_weth_transfers") == nil
      SanitizeIncorrectWETHTokenTransfers.start_link([])
      wait_for_migration_status_updated("wait_for_enabling_weth_filtering")

      # Only token transfer corresponding to transfer log should remain. Withdrawal related token transfer is removed.

      token_address_hash = token_address.hash
      transfer_log_index = transfer_log.index

      assert [
               %{token_contract_address_hash: ^token_address_hash, log_index: ^transfer_log_index}
             ] = Repo.all(TokenTransfer, order_by: [asc: :block_number, asc: :log_index])
    end

    test "Does not delete unique deposits and withdrawals", %{token_address: token_address, burn_address: burn_address} do
      %{log: deposit_log, token_transfer: _deposit_token_transfer} =
        insert_original_log_and_token_transfer(:deposit, token_address, burn_address)

      %{log: withdrawal_log, token_transfer: _withdrawal_token_transfer} =
        insert_original_log_and_token_transfer(:withdrawal, token_address, burn_address)

      assert MigrationStatus.get_status("sanitize_incorrect_weth_transfers") == nil
      SanitizeIncorrectWETHTokenTransfers.start_link([])
      wait_for_migration_status_updated("wait_for_enabling_weth_filtering")

      token_address_hash = token_address.hash
      deposit_log_index = deposit_log.index
      withdrawal_log_index = withdrawal_log.index

      assert [
               %{token_contract_address_hash: ^token_address_hash, log_index: ^deposit_log_index},
               %{token_contract_address_hash: ^token_address_hash, log_index: ^withdrawal_log_index}
             ] = Repo.all(TokenTransfer, order_by: [asc: :block_number, asc: :log_index])
    end

    test "Does not delete duplicated transfers", %{token_address: token_address} do
      %{log: transfer_log, token_transfer: transfer_token_transfer} =
        insert_original_log_and_token_transfer(:transfer, token_address)

      %{log: duplicated_transfer_log, token_transfer: _duplicated_transfer_token_transfer} =
        insert_duplicated_log_and_token_transfer(:transfer, transfer_log, transfer_token_transfer)

      assert MigrationStatus.get_status("sanitize_incorrect_weth_transfers") == nil
      SanitizeIncorrectWETHTokenTransfers.start_link([])
      wait_for_migration_status_updated("wait_for_enabling_weth_filtering")

      token_address_hash = token_address.hash
      transfer_log_index = transfer_log.index
      duplicated_transfer_log_index = duplicated_transfer_log.index

      assert [
               %{token_contract_address_hash: ^token_address_hash, log_index: ^transfer_log_index},
               %{token_contract_address_hash: ^token_address_hash, log_index: ^duplicated_transfer_log_index}
             ] = Repo.all(TokenTransfer, order_by: [asc: :block_number, asc: :log_index])
    end
  end

  describe "SanitizeIncorrectWETHTokenTransfers deletes not whitelisted transfers" do
    setup [:setup_whitelist]

    test "Deletes not whitelisted deposits/withdrawals", %{burn_address: burn_address} do
      %{contract_address: not_whitelisted_token_address} = insert(:token, type: "ERC-20")

      %{log: deposit_log, token_transfer: _deposit_token_transfer} =
        insert_original_log_and_token_transfer(:deposit, not_whitelisted_token_address, burn_address)

      %{log: withdrawal_log, token_transfer: _withdrawal_token_transfer} =
        insert_original_log_and_token_transfer(:withdrawal, not_whitelisted_token_address, burn_address)

      assert MigrationStatus.get_status("sanitize_incorrect_weth_transfers") == nil
      SanitizeIncorrectWETHTokenTransfers.start_link([])
      wait_for_migration_status_updated("completed")

      assert [] = Repo.all(TokenTransfer, order_by: [asc: :block_number, asc: :log_index])
    end

    test "Does not delete whitelisted deposits/withdrawals", %{
      token_address: whitelisted_token_address,
      burn_address: burn_address
    } do
      %{log: deposit_log, token_transfer: _deposit_token_transfer} =
        insert_original_log_and_token_transfer(:deposit, whitelisted_token_address, burn_address)

      %{log: withdrawal_log, token_transfer: _withdrawal_token_transfer} =
        insert_original_log_and_token_transfer(:withdrawal, whitelisted_token_address, burn_address)

      assert MigrationStatus.get_status("sanitize_incorrect_weth_transfers") == nil
      SanitizeIncorrectWETHTokenTransfers.start_link([])
      wait_for_migration_status_updated("completed")

      token_address_hash = whitelisted_token_address.hash
      deposit_log_index = deposit_log.index
      withdrawal_log_index = withdrawal_log.index

      assert [
               %{token_contract_address_hash: ^token_address_hash, log_index: ^deposit_log_index},
               %{token_contract_address_hash: ^token_address_hash, log_index: ^withdrawal_log_index}
             ] = Repo.all(TokenTransfer, order_by: [asc: :block_number, asc: :log_index])
    end
  end

  defp wait_for_migration_status_updated(expected) do
    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"sanitize_incorrect_weth_transfers" and ms.status == ^expected
        )
      )
    end)
  end

  defp insert_original_log_and_token_transfer(:deposit, token_address, burn_address) do
    insert_original_log_and_token_transfer(
      TokenTransfer.weth_deposit_signature(),
      token_address,
      burn_address,
      insert(:address)
    )
  end

  defp insert_original_log_and_token_transfer(:withdrawal, token_address, burn_address) do
    insert_original_log_and_token_transfer(
      TokenTransfer.weth_withdrawal_signature(),
      token_address,
      insert(:address),
      burn_address
    )
  end

  defp insert_original_log_and_token_transfer(:transfer, token_address) do
    insert_original_log_and_token_transfer(TokenTransfer.constant(), token_address, insert(:address), insert(:address))
  end

  defp insert_original_log_and_token_transfer(first_topic, token_address, from_address, to_address) do
    log = insert(:log, first_topic: first_topic, address: token_address)

    token_transfer =
      insert(:token_transfer,
        from_address: from_address,
        to_address: to_address,
        token_contract_address: log.address,
        block: log.block,
        transaction: log.transaction,
        log_index: log.index
      )

    %{log: log, token_transfer: token_transfer}
  end

  defp insert_duplicated_log_and_token_transfer(:deposit, original_log, original_token_transfer) do
    insert_duplicated_log_and_token_transfer(
      TokenTransfer.weth_deposit_signature(),
      original_log,
      original_token_transfer
    )
  end

  defp insert_duplicated_log_and_token_transfer(:withdrawal, original_log, original_token_transfer) do
    insert_duplicated_log_and_token_transfer(
      TokenTransfer.weth_withdrawal_signature(),
      original_log,
      original_token_transfer
    )
  end

  defp insert_duplicated_log_and_token_transfer(:transfer, original_log, original_token_transfer) do
    insert_duplicated_log_and_token_transfer(TokenTransfer.constant(), original_log, original_token_transfer)
  end

  defp insert_duplicated_log_and_token_transfer(first_topic, original_log, original_token_transfer) do
    log =
      insert(
        :log,
        first_topic: first_topic,
        address: original_log.address,
        transaction: original_log.transaction,
        block: original_log.block
      )

    token_transfer =
      insert(
        :token_transfer,
        from_address: original_token_transfer.from_address,
        to_address: original_token_transfer.to_address,
        token_contract_address: original_token_transfer.token_contract_address,
        block: original_token_transfer.block,
        transaction: original_token_transfer.transaction,
        log_index: log.index,
        amount: original_token_transfer.amount
      )

    %{log: log, token_transfer: token_transfer}
  end

  ########## Setup methods ##########

  defp setup_explorer_chain_token_transfer_env(_context) do
    # We may change the (:explorer, Explorer.Chain.TokenTransfer) envs throughout the tests.
    # That callback restores its initial value after the test is done.
    env = Application.get_env(:explorer, Explorer.Chain.TokenTransfer)
    assert Keyword.get(env, :weth_token_transfers_filtering_enabled) == false

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Chain.TokenTransfer, env)
    end)
  end

  defp setup_explorer_migrator_sanitize_incorrect_weth_token_transfers_env(_context) do
    env = Application.get_env(:explorer, Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers)

    Application.put_env(:explorer, Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers,
      batch_size: 1,
      concurrency: 1,
      timeout: 0
    )

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers, env)
    end)
  end

  defp setup_common_tokens_and_addresses(_context) do
    %{contract_address: token_address} = insert(:token, type: "ERC-20")
    burn_address = insert(:address, hash: "0x0000000000000000000000000000000000000000")

    %{burn_address: burn_address, token_address: token_address}
  end

  defp setup_whitelist(%{token_address: token_address}) do
    env = Application.get_env(:explorer, Explorer.Chain.TokenTransfer)

    Application.put_env(
      :explorer,
      Explorer.Chain.TokenTransfer,
      env
      |> Keyword.put(:whitelisted_weth_contracts, [token_address |> to_string() |> String.downcase()])
      |> Keyword.put(:weth_token_transfers_filtering_enabled, true)
    )
  end
end
