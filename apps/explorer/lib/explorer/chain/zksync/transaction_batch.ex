defmodule Explorer.Chain.ZkSync.TransactionBatch do
  @moduledoc "Models a batch of transactions for ZkSync."

  use Explorer.Schema

  alias Explorer.Chain.{
    Block,
    Hash,
    Wei
  }

  alias Explorer.Chain.ZkSync.{BatchTransaction, LifecycleTransaction}

  @optional_attrs ~w(commit_id prove_id execute_id)a

  @required_attrs ~w(number timestamp l1_transaction_count l2_transaction_count root_hash l1_gas_price l2_fair_gas_price start_block end_block)a

  @type t :: %__MODULE__{
          number: non_neg_integer(),
          timestamp: DateTime.t(),
          l1_transaction_count: non_neg_integer(),
          l2_transaction_count: non_neg_integer(),
          root_hash: Hash.t(),
          l1_gas_price: Wei.t(),
          l2_fair_gas_price: Wei.t(),
          start_block: Block.block_number(),
          end_block: Block.block_number(),
          commit_id: non_neg_integer() | nil,
          commit_transaction: %Ecto.Association.NotLoaded{} | LifecycleTransaction.t() | nil,
          prove_id: non_neg_integer() | nil,
          prove_transaction: %Ecto.Association.NotLoaded{} | LifecycleTransaction.t() | nil,
          execute_id: non_neg_integer() | nil,
          execute_transaction: %Ecto.Association.NotLoaded{} | LifecycleTransaction.t() | nil
        }

  @primary_key {:number, :integer, autogenerate: false}
  schema "zksync_transaction_batches" do
    field(:timestamp, :utc_datetime_usec)
    field(:l1_transaction_count, :integer)
    field(:l2_transaction_count, :integer)
    field(:root_hash, Hash.Full)
    field(:l1_gas_price, Wei)
    field(:l2_fair_gas_price, Wei)
    field(:start_block, :integer)
    field(:end_block, :integer)

    belongs_to(:commit_transaction, LifecycleTransaction,
      foreign_key: :commit_id,
      references: :id,
      type: :integer
    )

    belongs_to(:prove_transaction, LifecycleTransaction,
      foreign_key: :prove_id,
      references: :id,
      type: :integer
    )

    belongs_to(:execute_transaction, LifecycleTransaction,
      foreign_key: :execute_id,
      references: :id,
      type: :integer
    )

    has_many(:l2_transactions, BatchTransaction, foreign_key: :batch_number)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:commit_id)
    |> foreign_key_constraint(:prove_id)
    |> foreign_key_constraint(:execute_id)
    |> unique_constraint(:number)
  end
end
