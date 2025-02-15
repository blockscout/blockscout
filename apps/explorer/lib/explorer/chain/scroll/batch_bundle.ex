defmodule Explorer.Chain.Scroll.BatchBundle do
  @moduledoc """
    Models a batch bundle for Scroll.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Scroll.BatchBundles

    Migrations:
    - Explorer.Repo.Scroll.Migrations.AddBatchesTables
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(final_batch_number finalize_transaction_hash finalize_block_number finalize_timestamp)a

  @typedoc """
    Descriptor of the batch bundle:
    * `final_batch_number` - The last batch number finalized in this bundle.
    * `finalize_transaction_hash` - A hash of the finalize transaction on L1.
    * `finalize_block_number` - A block number of the finalize transaction on L1.
    * `finalize_timestamp` - A timestamp of the finalize block.
  """
  @type to_import :: %{
          final_batch_number: non_neg_integer(),
          finalize_transaction_hash: binary(),
          finalize_block_number: non_neg_integer(),
          finalize_timestamp: DateTime.t()
        }

  @typedoc """
    * `id` - An internal ID of the bundle.
    * `final_batch_number` - The last batch number finalized in this bundle.
    * `finalize_transaction_hash` - A hash of the finalize transaction on L1.
    * `finalize_block_number` - A block number of the finalize transaction on L1.
    * `finalize_timestamp` - A timestamp of the finalize block.
  """
  @primary_key {:id, :id, autogenerate: true}
  typed_schema "scroll_batch_bundles" do
    field(:final_batch_number, :integer)
    field(:finalize_transaction_hash, Hash.Full)
    field(:finalize_block_number, :integer)
    field(:finalize_timestamp, :utc_datetime_usec)
    timestamps()
  end

  @doc """
    Checks that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = bundles, attrs \\ %{}) do
    bundles
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
  end
end
