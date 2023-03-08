defmodule Explorer.Chain.OptimismFrameSequence do
  @moduledoc "Models a frame sequence for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, OptimismTxnBatch}

  @required_attrs ~w(id l1_transaction_hashes l1_timestamp)a

  @type t :: %__MODULE__{
          l1_transaction_hashes: [Hash.t()],
          l1_timestamp: DateTime.t()
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "op_frame_sequences" do
    field(:l1_transaction_hashes, {:array, Hash.Full})
    field(:l1_timestamp, :utc_datetime_usec)

    has_many(:transaction_batches, OptimismTxnBatch, foreign_key: :frame_sequence_id)

    timestamps()
  end

  def changeset(%__MODULE__{} = sequences, attrs \\ %{}) do
    sequences
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
  end
end
