defmodule Explorer.Chain.ZkevmTxnBatch do
  @moduledoc "Models a batch of transactions for zkEVM."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, ZkevmBatchTxn, ZkevmLifecycleTxn}

  @optional_attrs ~w(sequence_id verify_id)a

  @required_attrs ~w(number timestamp global_exit_root acc_input_hash state_root)a

  @type t :: %__MODULE__{
          number: non_neg_integer(),
          timestamp: DateTime.t(),
          global_exit_root: Hash.t(),
          acc_input_hash: Hash.t(),
          state_root: Hash.t(),
          sequence_id: non_neg_integer() | nil,
          sequence_transaction: %Ecto.Association.NotLoaded{} | ZkevmLifecycleTxn.t() | nil,
          verify_id: non_neg_integer() | nil,
          verify_transaction: %Ecto.Association.NotLoaded{} | ZkevmLifecycleTxn.t() | nil,
          l2_transactions: %Ecto.Association.NotLoaded{} | [ZkevmBatchTxn.t()]
        }

  @primary_key {:number, :integer, autogenerate: false}
  schema "zkevm_transaction_batches" do
    field(:timestamp, :utc_datetime_usec)
    field(:global_exit_root, Hash.Full)
    field(:acc_input_hash, Hash.Full)
    field(:state_root, Hash.Full)

    belongs_to(:sequence_transaction, ZkevmLifecycleTxn, foreign_key: :sequence_id, references: :id, type: :integer)
    belongs_to(:verify_transaction, ZkevmLifecycleTxn, foreign_key: :verify_id, references: :id, type: :integer)

    has_many(:l2_transactions, ZkevmBatchTxn, foreign_key: :batch_number)

    timestamps()
  end

  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:sequence_id)
    |> foreign_key_constraint(:verify_id)
    |> unique_constraint(:number)
  end
end
