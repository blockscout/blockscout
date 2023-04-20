defmodule Explorer.Chain.ZkevmTxnBatch do
  @moduledoc "Models a batch of transactions for zkEVM."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, ZkevmLifecycleTxn}

  @required_attrs ~w(number timestamp l2_transaction_hashes global_exit_root acc_input_hash state_root sequence_id verify_id)a

  @type t :: %__MODULE__{
          number: non_neg_integer(),
          timestamp: DateTime.t(),
          l2_transaction_hashes: [Hash.t()],
          global_exit_root: Hash.t(),
          acc_input_hash: Hash.t(),
          state_root: Hash.t(),
          sequence_id: non_neg_integer() | nil,
          sequence_transaction: %Ecto.Association.NotLoaded{} | ZkevmLifecycleTxn.t() | nil,
          verify_id: non_neg_integer() | nil,
          verify_transaction: %Ecto.Association.NotLoaded{} | ZkevmLifecycleTxn.t() | nil
        }

  @primary_key false
  schema "zkevm_transaction_batches" do
    field(:number, :integer, primary_key: true)
    field(:timestamp, :utc_datetime_usec)
    field(:l2_transaction_hashes, {:array, Hash.Full})
    field(:global_exit_root, Hash.Full)
    field(:acc_input_hash, Hash.Full)
    field(:state_root, Hash.Full)

    belongs_to(:sequence_transaction, ZkevmLifecycleTxn, foreign_key: :sequence_id, references: :id, type: :integer)
    belongs_to(:verify_transaction, ZkevmLifecycleTxn, foreign_key: :verify_id, references: :id, type: :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:sequence_id)
    |> foreign_key_constraint(:verify_id)
  end
end
