defmodule Explorer.Chain.Optimism.FrameSequence do
  @moduledoc """
    Models a frame sequence for Optimism.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Optimism.FrameSequences

    Migrations:
    - Explorer.Repo.Migrations.AddOpFrameSequencesTable
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Chain.Optimism.{FrameSequenceBlob, TxnBatch}

  @required_attrs ~w(id l1_transaction_hashes l1_timestamp)a

  @type t :: %__MODULE__{
          l1_transaction_hashes: [Hash.t()],
          l1_timestamp: DateTime.t(),
          transaction_batches: %Ecto.Association.NotLoaded{} | [TxnBatch.t()],
          blobs: %Ecto.Association.NotLoaded{} | [FrameSequenceBlob.t()]
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "op_frame_sequences" do
    field(:l1_transaction_hashes, {:array, Hash.Full})
    field(:l1_timestamp, :utc_datetime_usec)

    has_many(:transaction_batches, TxnBatch, foreign_key: :frame_sequence_id)
    has_many(:blobs, FrameSequenceBlob, foreign_key: :frame_sequence_id)

    timestamps()
  end

  @doc """
    Validates that the attributes are valid.
  """
  def changeset(%__MODULE__{} = sequences, attrs \\ %{}) do
    sequences
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
  end
end
