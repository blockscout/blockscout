defmodule Explorer.Accounts.TagTransaction do
  @moduledoc """
    This is a personal tag for transaction
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Explorer.Accounts.Identity
  alias Explorer.Chain.{Hash, Transaction}

  schema "account_tag_transactions" do
    field(:name, :string)
    belongs_to(:identity, Identity)

    belongs_to(:transaction, Transaction,
      foreign_key: :tx_hash,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :identity_id, :tx_hash])
    |> validate_required([:name, :identity_id, :tx_hash])
  end
end
