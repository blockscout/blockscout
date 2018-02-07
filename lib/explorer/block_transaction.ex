defmodule Explorer.BlockTransaction do
  @moduledoc false
  alias Explorer.BlockTransaction
  import Ecto.Changeset
  use Ecto.Schema

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  @primary_key false
  schema "block_transactions" do
    belongs_to :block, Explorer.Block
    belongs_to :transaction, Explorer.Transaction, primary_key: true
    timestamps()
  end

  @required_attrs ~w(block_id transaction_id)a

  def changeset(%BlockTransaction{} = block_transaction, attrs \\ %{}) do
    block_transaction
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> cast_assoc(:block)
    |> cast_assoc(:transaction)
  end
end
