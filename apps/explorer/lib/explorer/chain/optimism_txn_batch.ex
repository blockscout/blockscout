defmodule Explorer.Chain.OptimismTxnBatch do
  @moduledoc "Models a batch of transactions for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.OptimismFrameSequence

  @required_attrs ~w(l2_block_number epoch_number frame_sequence_id)a

  @type t :: %__MODULE__{
          l2_block_number: non_neg_integer(),
          epoch_number: non_neg_integer(),
          frame_sequence_id: non_neg_integer()
        }

  @primary_key false
  schema "op_transaction_batches" do
    field(:l2_block_number, :integer, primary_key: true)
    field(:epoch_number, :integer)
    belongs_to(:frame_sequence, OptimismFrameSequence, foreign_key: :frame_sequence_id, references: :id, type: :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:frame_sequence_id)
  end
end
