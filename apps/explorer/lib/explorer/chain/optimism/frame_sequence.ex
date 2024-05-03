defmodule Explorer.Chain.Optimism.FrameSequence do
  @moduledoc "Models a frame sequence for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.{Data, Hash}
  alias Explorer.Chain.Optimism.TxnBatch

  @required_attrs ~w(id l1_transaction_hashes l1_timestamp)a
  @optional_attrs ~w(celestia_blob_height celestia_blob_namespace celestia_blob_commitment)a

  @type t :: %__MODULE__{
          l1_transaction_hashes: [Hash.t()],
          l1_timestamp: DateTime.t(),
          celestia_blob_height: non_neg_integer() | nil,
          celestia_blob_namespace: Data.t() | nil,
          celestia_blob_commitment: Data.t() | nil,
          transaction_batches: %Ecto.Association.NotLoaded{} | [TxnBatch.t()]
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "op_frame_sequences" do
    field(:l1_transaction_hashes, {:array, Hash.Full})
    field(:l1_timestamp, :utc_datetime_usec)
    field(:celestia_blob_height, :integer)
    field(:celestia_blob_namespace, Data)
    field(:celestia_blob_commitment, Data)

    has_many(:transaction_batches, TxnBatch, foreign_key: :frame_sequence_id)

    timestamps()
  end

  def changeset(%__MODULE__{} = sequences, attrs \\ %{}) do
    sequences
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
  end
end
