# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.SignedAuthorization.ReaderTest do
  use Explorer.DataCase

  alias Explorer.Chain.Block
  alias Explorer.Chain.SignedAuthorization.Reader

  describe "address_hashes_to_latest_authorizations/1" do
    test "counts only authorizations of transactions in consensus blocks" do
      authority = insert(:address)

      consensus_transaction = :transaction |> insert(type: 4) |> with_block(insert(:block, consensus: true))
      non_consensus_transaction = :transaction |> insert(type: 4) |> with_non_consensus_block()
      pending_transaction = insert(:transaction, type: 4)

      insert(:signed_authorization,
        transaction: consensus_transaction,
        authority: authority.hash,
        nonce: 5,
        status: :ok
      )

      insert(:signed_authorization,
        transaction: non_consensus_transaction,
        authority: authority.hash,
        nonce: 9,
        status: :ok
      )

      insert(:signed_authorization, transaction: pending_transaction, authority: authority.hash, nonce: 12, status: :ok)

      assert [%{authority: result_authority, nonce: nonce}] =
               Reader.address_hashes_to_latest_authorizations([authority.hash])

      assert result_authority == authority.hash
      assert Decimal.eq?(nonce, 5)
    end
  end

  describe "transaction_hashes_to_block_hashes/1" do
    test "returns block hashes for transactions in blocks with and without consensus" do
      consensus_block = insert(:block, consensus: true)

      consensus_transaction = :transaction |> insert() |> with_block(consensus_block)
      non_consensus_transaction = :transaction |> insert() |> with_non_consensus_block()
      pending_transaction = insert(:transaction)

      assert Reader.transaction_hashes_to_block_hashes([
               consensus_transaction.hash,
               non_consensus_transaction.hash,
               pending_transaction.hash
             ]) == %{
               consensus_transaction.hash => consensus_block.hash,
               non_consensus_transaction.hash => non_consensus_transaction.block_hash
             }
    end

    test "returns an empty map for an empty list" do
      assert Reader.transaction_hashes_to_block_hashes([]) == %{}
    end
  end

  # The factory puts a transaction only into a consensus block, so the block loses consensus after that.
  defp with_non_consensus_block(transaction) do
    block = insert(:block, consensus: true)
    transaction = with_block(transaction, block)

    block |> Block.changeset(%{consensus: false}) |> Repo.update!()

    transaction
  end
end
