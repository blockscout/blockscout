defmodule ExplorerWeb.Factory do
  import Ecto.Query
  import Explorer.Factory

  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Repo

  def with_block(%Transaction{index: nil} = transaction, %Block{hash: block_hash}) do
    next_transaction_index = block_hash_to_next_transaction_index(block_hash)

    transaction
    |> Transaction.changeset(%{block_hash: block_hash, index: next_transaction_index})
    |> Repo.update!()
    |> Repo.preload(:block)
  end

  def with_receipt(%Transaction{hash: hash, index: index} = transaction) do
    insert(:receipt, transaction_hash: hash, transaction_index: index)

    Repo.preload(transaction, :receipt)
  end

  defp block_hash_to_next_transaction_index(block_hash) do
    query =
      from(
        transaction in Transaction,
        select: transaction.index,
        where: transaction.block_hash == ^block_hash
      )

    Repo.one!(query) + 1
  end
end
