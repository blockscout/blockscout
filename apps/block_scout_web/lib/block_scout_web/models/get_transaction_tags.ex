defmodule GetTransactionTags do
  @moduledoc """
  Get various types of tags associated with the transaction
  """

  # import Ecto.Query, only: [from: 2]

  alias Explorer.Accounts.TagTransaction
  alias Explorer.Chain.Hash
  alias Explorer.Repo

  def get_transaction_tags(transaction_hash, %{id: identity_id}) do
    Repo.get_by(TagTransaction, tx_hash: transaction_hash, identity_id: identity_id)
  end

  def get_transaction_tags(_, _), do: nil
end
