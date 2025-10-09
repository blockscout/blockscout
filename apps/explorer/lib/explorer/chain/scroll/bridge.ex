defmodule Explorer.Chain.Scroll.Bridge do
  @moduledoc """
    Models a bridge operation for Scroll.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Scroll.BridgeOperations

    Migrations:
    - Explorer.Repo.Scroll.Migrations.AddBridgeTable
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @optional_attrs ~w(index l1_transaction_hash l2_transaction_hash amount block_number block_timestamp)a

  @required_attrs ~w(type message_hash)a

  @typedoc """
    Descriptor of the Scroll bridge message:
    * `type` - Type of the bridge operation (:deposit or :withdrawal).
    * `index` - Index of the deposit or index of the withdrawal (can be nil).
    * `l1_transaction_hash` - L1 transaction hash of the bridge operation (can be nil).
    * `l2_transaction_hash` - L2 transaction hash of the bridge operation (can be nil).
    * `amount` - Amount of the operation in native token (can be nil).
    * `block_number` - Block number of deposit operation for `l1_transaction_hash`
                       or withdrawal operation for `l2_transaction_hash` (can be nil).
    * `block_timestamp` - Timestamp of the block `block_number` (can be nil).
    * `message_hash` - Unique hash of the operation (message).
  """
  @type to_import :: %{
          type: :deposit | :withdrawal,
          index: non_neg_integer() | nil,
          l1_transaction_hash: binary() | nil,
          l2_transaction_hash: binary() | nil,
          amount: non_neg_integer() | nil,
          block_number: non_neg_integer() | nil,
          block_timestamp: DateTime.t() | nil,
          message_hash: binary()
        }

  @typedoc """
    * `type` - Type of the bridge operation (:deposit or :withdrawal).
    * `index` - Index of the deposit or index of the withdrawal (can be nil).
    * `l1_transaction_hash` - L1 transaction hash of the bridge operation (can be nil).
    * `l2_transaction_hash` - L2 transaction hash of the bridge operation (can be nil).
    * `amount` - Amount of the operation in native token (can be nil).
    * `block_number` - Block number of deposit operation for `l1_transaction_hash`
                       or withdrawal operation for `l2_transaction_hash` (can be nil).
    * `block_timestamp` - Timestamp of the block `block_number` (can be nil).
    * `message_hash` - Unique hash of the operation (message).
  """
  @primary_key false
  typed_schema "scroll_bridge" do
    field(:type, Ecto.Enum, values: [:deposit, :withdrawal], primary_key: true)
    field(:index, :integer)
    field(:l1_transaction_hash, Hash.Full)
    field(:l2_transaction_hash, Hash.Full)
    field(:amount, :decimal)
    field(:block_number, :integer)
    field(:block_timestamp, :utc_datetime_usec)
    field(:message_hash, Hash.Full, primary_key: true)

    timestamps()
  end

  @doc """
    Checks that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = operations, attrs \\ %{}) do
    operations
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:type, :message_hash])
  end
end
