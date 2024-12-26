defmodule Explorer.Chain.Scroll.Batch do
  @moduledoc """
    Models a batch for Scroll.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Scroll.Batches

    Migrations:
    - Explorer.Repo.Scroll.Migrations.AddBatchesTables
  """

  use Explorer.Schema

  alias Explorer.Chain.Block.Range, as: BlockRange
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Scroll.BatchBundle

  @optional_attrs ~w(bundle_id)a

  @required_attrs ~w(number commit_transaction_hash commit_block_number commit_timestamp l2_block_range container)a

  @typedoc """
    Descriptor of the batch:
    * `number` - A unique batch number.
    * `commit_transaction_hash` - A hash of the commit transaction on L1.
    * `commit_block_number` - A block number of the commit transaction on L1.
    * `commit_timestamp` - A timestamp of the commit block.
    * `bundle_id` - An identifier of the batch bundle from the `scroll_batch_bundles` database table.
    * `l2_block_range` - A range of L2 blocks included into the batch.
    * `container` - A container where the batch info is mostly located (can be :in_calldata, :in_blob4844).
  """
  @type to_import :: %{
          number: non_neg_integer(),
          commit_transaction_hash: binary(),
          commit_block_number: non_neg_integer(),
          commit_timestamp: DateTime.t(),
          bundle_id: non_neg_integer() | nil,
          l2_block_range: BlockRange.t(),
          container: :in_calldata | :in_blob4844
        }

  @typedoc """
    * `number` - A unique batch number.
    * `commit_transaction_hash` - A hash of the commit transaction on L1.
    * `commit_block_number` - A block number of the commit transaction on L1.
    * `commit_timestamp` - A timestamp of the commit block.
    * `bundle_id` - An identifier of the batch bundle from the `scroll_batch_bundles` database table.
    * `l2_block_range` - A range of L2 blocks included into the batch.
    * `container` - A container where the batch info is mostly located (can be :in_calldata, :in_blob4844).
  """
  @primary_key false
  typed_schema "scroll_batches" do
    field(:number, :integer, primary_key: true)
    field(:commit_transaction_hash, Hash.Full)
    field(:commit_block_number, :integer)
    field(:commit_timestamp, :utc_datetime_usec)

    belongs_to(:bundle, BatchBundle,
      foreign_key: :bundle_id,
      references: :id,
      type: :integer,
      null: true
    )

    field(:l2_block_range, BlockRange, null: false)
    field(:container, Ecto.Enum, values: [:in_blob4844, :in_calldata])

    timestamps()
  end

  @doc """
    Checks that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:number)
    |> foreign_key_constraint(:bundle_id)
  end
end
