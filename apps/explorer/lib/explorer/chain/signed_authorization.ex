defmodule Explorer.Chain.SignedAuthorization do
  @moduledoc "Models a transaction extension with authorization tuples from eip7702 set code transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Transaction}

  @required_attrs ~w(transaction_hash index chain_id address nonce r s v)a

  @type t :: %__MODULE__{
          transaction_hash: Hash.Full,
          index: :integer,
          chain_id: :integer,
          address: Hash.Address,
          nonce: :integer,
          r: :decimal,
          s: :decimal,
          v: :integer,
          authority: Hash.Address
        }

  @primary_key false
  schema "signed_authorizations" do
    field(:index, :integer)
    field(:chain_id, :integer)
    field(:address, Hash.Address)
    field(:nonce, :integer)
    field(:r, :decimal)
    field(:s, :decimal)
    field(:v, :integer)
    field(:authority, Hash.Address)

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = struct, attrs \\ %{}) do
    struct
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_hash)
  end
end
