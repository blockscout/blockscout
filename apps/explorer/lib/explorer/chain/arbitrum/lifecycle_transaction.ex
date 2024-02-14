defmodule Explorer.Chain.Arbitrum.LifecycleTransaction do
  @moduledoc "Models an L1 lifecycle transaction for Arbitrum."

  use Explorer.Schema

  alias Explorer.Chain.{
    Block,
    Hash
  }

  alias Explorer.Chain.Arbitrum.{BatchBlock, L1Batch}

  @required_attrs ~w(id hash block timestamp status)a

  @type t :: %__MODULE__{
          hash: Hash.t(),
          block: Block.block_number(),
          timestamp: DateTime.t(),
          status: String.t()
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "arbitrum_lifecycle_l1_transactions" do
    field(:hash, Hash.Full)
    field(:block, :integer)
    field(:timestamp, :utc_datetime_usec)
    field(:status, Ecto.Enum, values: [:unfinalized, :finalized])

    has_many(:committed_batches, L1Batch, foreign_key: :commit_id)
    has_many(:confirmed_blocks, BatchBlock, foreign_key: :confirm_id)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = txn, attrs \\ %{}) do
    txn
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
  end
end
