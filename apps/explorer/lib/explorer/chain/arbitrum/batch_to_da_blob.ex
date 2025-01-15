defmodule Explorer.Chain.Arbitrum.BatchToDaBlob do
  @moduledoc """
    Models a link between an Arbitrum L1 batch and its corresponding data blob.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.BatchesToDaBlobs

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.AddDataBlobsToBatchesTable
  """

  use Explorer.Schema

  alias Explorer.Chain.Arbitrum.{DaMultiPurposeRecord, L1Batch}
  alias Explorer.Chain.Hash

  @required_attrs ~w(batch_number data_blob_id)a

  @typedoc """
  Descriptor of the link between an Arbitrum L1 batch and its data blob:
    * `batch_number` - The number of the Arbitrum batch.
    * `data_blob_id` - The hash of the data blob.
  """
  @type to_import :: %{
          batch_number: non_neg_integer(),
          data_blob_id: binary()
        }

  @typedoc """
    * `batch_number` - The number of the Arbitrum batch.
    * `data_blob_id` - The hash of the data blob.
    * `batch` - An instance of `Explorer.Chain.Arbitrum.L1Batch` referenced by `batch_number`.
    * `da_record` - An instance of `Explorer.Chain.Arbitrum.DaMultiPurposeRecord` referenced by `data_blob_id`.
  """
  @primary_key {:batch_number, :integer, autogenerate: false}
  typed_schema "arbitrum_batches_to_da_blobs" do
    belongs_to(:batch, L1Batch,
      foreign_key: :batch_number,
      references: :number,
      define_field: false
    )

    belongs_to(:da_record, DaMultiPurposeRecord,
      foreign_key: :data_blob_id,
      references: :data_key,
      type: Hash.Full
    )

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = batch_to_da_blob, attrs \\ %{}) do
    batch_to_da_blob
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:batch_number)
    |> foreign_key_constraint(:data_blob_id)
    |> unique_constraint(:batch_number)
  end
end
