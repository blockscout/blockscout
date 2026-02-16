defmodule Explorer.Chain.Signet.Fill do
  @moduledoc """
    Models a Signet Filled event from RollupOrders or HostOrders contracts.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Signet.Fills

    Migrations:
    - Explorer.Repo.Signet.Migrations.CreateSignetTables
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @insert_result_key :insert_signet_fills

  @optional_attrs ~w()a

  @required_attrs ~w(outputs_witness_hash chain_type block_number transaction_hash log_index outputs_json)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  Descriptor of a Signet Filled event:
    * `outputs_witness_hash` - keccak256 hash of outputs for correlation with orders
    * `chain_type` - Whether this fill occurred on :rollup or :host chain
    * `block_number` - The block number where the fill was executed
    * `transaction_hash` - The hash of the transaction containing the fill
    * `log_index` - The index of the log within the transaction
    * `outputs_json` - JSON-encoded array of filled outputs
  """
  @type to_import :: %{
          outputs_witness_hash: binary(),
          chain_type: :rollup | :host,
          block_number: non_neg_integer(),
          transaction_hash: binary(),
          log_index: non_neg_integer(),
          outputs_json: String.t()
        }

  @primary_key false
  typed_schema "signet_fills" do
    field(:outputs_witness_hash, Hash.Full, primary_key: true)
    field(:chain_type, Ecto.Enum, values: [:rollup, :host], primary_key: true)
    field(:block_number, :integer)
    field(:transaction_hash, Hash.Full)
    field(:log_index, :integer)
    field(:outputs_json, :string)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = fill, attrs \\ %{}) do
    fill
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:outputs_witness_hash, :chain_type])
  end

  @doc """
  Shared result key used by import runners to return inserted Signet fills.
  """
  @spec insert_result_key() :: atom()
  def insert_result_key, do: @insert_result_key
end
