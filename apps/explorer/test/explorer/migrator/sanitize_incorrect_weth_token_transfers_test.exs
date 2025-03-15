defmodule Explorer.Migrator.SanitizeIncorrectWETHTokenTransfersTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.TokenTransfer
  alias Explorer.Migrator.{SanitizeIncorrectWETHTokenTransfers, MigrationStatus}
  alias Explorer.Repo

  describe "SanitizeIncorrectWETHTokenTransfers" do
    test "Deletes not whitelisted WETH transfers and duplicated WETH transfers" do
      %{contract_address: token_address} = insert(:token, type: "ERC-20")
      block = insert(:block, consensus: true)
      burn_address = insert(:address, hash: "0x0000000000000000000000000000000000000000")

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

      Application.put_env(:explorer, Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers,
        batch_size: 1,
        concurrency: 1,
        timeout: 0
      )

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

      Application.put_env(:explorer, Explorer.Chain.TokenTransfer, env)
    end
  end
end
