defmodule Explorer.Migrator.SanitizeIncorrectNFTTokenTransfersTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{Block, TokenTransfer}
  alias Explorer.Migrator.{SanitizeIncorrectNFTTokenTransfers, MigrationStatus}
  alias Explorer.Repo

  describe "Migrate token transfers" do
    test "Handles delete and re-fetch" do
      %{contract_address: token_address} = insert(:token, type: "ERC-721")
      block = insert(:block, consensus: true)

      insert(:token_transfer,
        from_address: insert(:address),
        block: block,
        block_number: block.number,
        token_contract_address: token_address,
        token_ids: nil,
        token_type: "ERC-721"
      )

      deposit_log = insert(:log, first_topic: TokenTransfer.weth_deposit_signature(), address: token_address)

      tt =
        insert(:token_transfer,
          from_address: insert(:address),
          token_contract_address: token_address,
          block: deposit_log.block,
          transaction: deposit_log.transaction,
          log_index: deposit_log.index
        )

      assert deposit_log.block_hash == tt.block_hash and deposit_log.transaction_hash == tt.transaction_hash and
               deposit_log.index == tt.log_index

      assert tt.token_contract_address_hash == deposit_log.address_hash

      withdrawal_log = insert(:log, first_topic: TokenTransfer.weth_withdrawal_signature(), address: token_address)

      insert(:token_transfer,
        from_address: insert(:address),
        token_contract_address: token_address,
        block: withdrawal_log.block,
        transaction: withdrawal_log.transaction,
        log_index: withdrawal_log.index
      )

      erc1155_token = insert(:token, type: "ERC-1155")

      insert(:token_transfer,
        from_address: insert(:address),
        token_contract_address: erc1155_token.contract_address,
        amount: nil,
        amounts: nil,
        token_ids: nil,
        token_type: "ERC-1155"
      )

      assert MigrationStatus.get_status("sanitize_incorrect_nft") == nil

      SanitizeIncorrectNFTTokenTransfers.start_link([])
      Process.sleep(100)

      assert MigrationStatus.get_status("sanitize_incorrect_nft") == "completed"

      token_address_hash = token_address.hash
      assert %{token_contract_address_hash: ^token_address_hash, token_ids: nil} = Repo.one(TokenTransfer)
      assert %{consensus: true, refetch_needed: true} = Repo.get_by(Block, hash: block.hash)
    end
  end
end
