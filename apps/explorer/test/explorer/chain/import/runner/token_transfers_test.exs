# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.TokenTransfersTest do
  use Explorer.DataCase

  alias Explorer.Chain
  alias Explorer.Chain.TokenTransfer

  describe "run/3" do
    test "does not insert the token transfers of the blocks that are not consensus anymore" do
      consensus_block = insert(:block, consensus: true)
      non_consensus_block = insert(:block, consensus: false)
      transaction = :transaction |> insert() |> with_block(consensus_block)
      token = insert(:token)
      from_address = insert(:address)
      to_address = insert(:address)

      token_transfer_params = fn block ->
        %{
          amount: Decimal.new(1),
          block_consensus: true,
          block_hash: block.hash,
          block_number: block.number,
          from_address_hash: from_address.hash,
          log_index: 0,
          to_address_hash: to_address.hash,
          token_contract_address_hash: token.contract_address_hash,
          token_type: "ERC-20",
          transaction_hash: transaction.hash
        }
      end

      assert {:ok, %{token_transfers: [%TokenTransfer{block_hash: block_hash}]}} =
               Chain.import(%{
                 token_transfers: %{
                   params: [token_transfer_params.(consensus_block), token_transfer_params.(non_consensus_block)]
                 }
               })

      assert block_hash == consensus_block.hash
      assert Repo.aggregate(TokenTransfer, :count) == 1
    end
  end
end
