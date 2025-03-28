defmodule Explorer.Chain.SignedAuthorization do
  @moduledoc "Models a transaction extension with authorization tuples from eip7702 set code transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Transaction}

  @optional_attrs ~w(authority)a
  @required_attrs ~w(transaction_hash index chain_id address nonce r s v)a

  @typedoc """
  Descriptor of the signed authorization tuple from EIP-7702 set code transactions:
    * `transaction_hash` - the hash of the associated transaction.
    * `index` - the index of this authorization in the authorization list.
    * `chain_id` - the ID of the chain for which the authorization was created.
    * `address` - the address of the delegate contract.
    * `nonce` - the signature nonce.
    * `v` - the 'v' component of the signature.
    * `r` - the 'r' component of the signature.
    * `s` - the 's' component of the signature.
    * `authority` - the signer of the authorization.
  """
  @type to_import :: %__MODULE__{
          transaction_hash: binary(),
          index: non_neg_integer(),
          chain_id: non_neg_integer(),
          address: binary(),
          nonce: non_neg_integer(),
          r: non_neg_integer(),
          s: non_neg_integer(),
          v: non_neg_integer(),
          authority: binary() | nil
        }

  @typedoc """
    * `transaction_hash` - the hash of the associated transaction.
    * `index` - the index of this authorization in the authorization list.
    * `chain_id` - the ID of the chain for which the authorization was created.
    * `address` - the address of the delegate contract.
    * `nonce` - the signature nonce.
    * `v` - the 'v' component of the signature.
    * `r` - the 'r' component of the signature.
    * `s` - the 's' component of the signature.
    * `authority` - the signer of the authorization.
    * `inserted_at` - timestamp indicating when the signed authorization was created.
    * `updated_at` - timestamp indicating when the signed authorization was last updated.
    * `transaction` - an instance of `Explorer.Chain.Transaction` referenced by `transaction_hash`.
  """
  @primary_key false
  typed_schema "signed_authorizations" do
    field(:index, :integer, primary_key: true, null: false)
    field(:chain_id, :integer, null: false)
    field(:address, Hash.Address, null: false)
    field(:nonce, :decimal, null: false)
    field(:r, :decimal, null: false)
    field(:s, :decimal, null: false)
    field(:v, :integer, null: false)
    field(:authority, Hash.Address, null: true)

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
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_hash)
  end
end
