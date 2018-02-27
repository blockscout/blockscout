defmodule Explorer.BlockTransaction do
  @moduledoc "Connects a Block to a Transaction"

  alias Explorer.BlockTransaction

  use Explorer.Schema

  @primary_key false
  schema "block_transactions" do
    belongs_to(:block, Explorer.Block)
    belongs_to(:transaction, Explorer.Transaction, primary_key: true)
    timestamps()
  end

  @required_attrs ~w(block_id transaction_id)a

  def changeset(%BlockTransaction{} = block_transaction, attrs \\ %{}) do
    block_transaction
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> cast_assoc(:block)
    |> cast_assoc(:transaction)
    |> unique_constraint(:transaction_id, name: :block_transactions_transaction_id_index)
  end
end
