defmodule Explorer.Chain.ZkSync.BatchBlock do
  @moduledoc "Models a list of blocks related to a batch for ZkSync."

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Chain.ZkSync.TransactionBatch

  @required_attrs ~w(batch_number hash)a

  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          batch: %Ecto.Association.NotLoaded{} | TransactionBatch.t() | nil,
          hash: Hash.t(),
          block: %Ecto.Association.NotLoaded{} | Block.t() | nil
        }

  @primary_key false
  schema "zksync_batch_l2_blocks" do
    belongs_to(:batch, TransactionBatch, foreign_key: :batch_number, references: :number, type: :integer)
    belongs_to(:block, Block, foreign_key: :hash, primary_key: true, references: :hash, type: Hash.Full)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = items, attrs \\ %{}) do
    items
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:batch_number)
    |> unique_constraint(:hash)
  end
end
