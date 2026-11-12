# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.SanitizeEip7708TokenTransfersTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{Hash, Token, TokenTransfer}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Migrator.{MigrationStatus, SanitizeEip7708TokenTransfers}
  alias Explorer.Repo

  describe "Migrate token transfers" do
    test "deletes token transfers, balances and token of the EIP-7708 system address" do
      {:ok, system_address_hash} = Hash.Address.cast(TokenTransfer.eip7708_system_address())
      system_address = insert(:address, hash: system_address_hash)
      insert(:token, contract_address: system_address, name: nil, symbol: nil, decimals: nil)

      for _ <- 1..3 do
        insert(:token_transfer, from_address: insert(:address), token_contract_address: system_address)
      end

      insert(:address_current_token_balance, token_contract_address_hash: system_address_hash)

      regular_transfer = insert(:token_transfer, from_address: insert(:address))
      regular_token_contract_address_hash = regular_transfer.token_contract_address_hash

      assert MigrationStatus.get_status("sanitize_eip7708_token_transfers") == nil

      SanitizeEip7708TokenTransfers.start_link([])
      Process.sleep(100)

      assert MigrationStatus.get_status("sanitize_eip7708_token_transfers") == "completed"

      assert [%TokenTransfer{token_contract_address_hash: ^regular_token_contract_address_hash}] =
               Repo.all(TokenTransfer)

      assert Repo.get_by(Token, contract_address_hash: system_address_hash) == nil
      assert Repo.get_by(CurrentTokenBalance, token_contract_address_hash: system_address_hash) == nil
      assert Repo.get_by(Token, contract_address_hash: regular_token_contract_address_hash)
    end
  end
end
