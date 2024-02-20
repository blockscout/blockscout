defmodule Explorer.Chain.Transaction.Fork do
  @moduledoc """
  A transaction fork has the same `hash` as a `t:Explorer.Chain.Transaction.t/0`, but associates that `hash` with a
  non-consensus uncle `t:Explorer.Chain.Block.t/0` instead of the consensus block linked in the
  `t:Explorer.Chain.Transaction.t/0` `block_hash`.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash, Transaction}

  @optional_attrs ~w()a
  @required_attrs ~w(hash index uncle_hash)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
   * `hash` - hash of contents of this transaction
   * `index` - index of this transaction in `uncle`.
   * `transaction` - the data shared between all forks and the consensus transaction.
   * `uncle` - the block in which this transaction was mined/validated.
   * `uncle_hash` - `uncle` foreign key.
  """
  @primary_key false
  typed_schema "transaction_forks" do
    field(:index, :integer, null: false)

    timestamps()

    belongs_to(:transaction, Transaction, foreign_key: :hash, references: :hash, type: Hash.Full, null: false)
    belongs_to(:uncle, Block, foreign_key: :uncle_hash, references: :hash, type: Hash.Full, null: false)
  end

  @doc """
  All fields are required for transaction fork

      iex> changeset = Fork.changeset(
      ...>   %Fork{},
      ...>   %{
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     index: 1,
      ...>     uncle_hash: "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b48"
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  """
  def changeset(%__MODULE__{} = fork, attrs \\ %{}) do
    fork
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> assoc_constraint(:transaction)
    |> assoc_constraint(:uncle)
  end
end
