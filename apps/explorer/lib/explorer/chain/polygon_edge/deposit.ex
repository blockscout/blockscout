defmodule Explorer.Chain.PolygonEdge.Deposit do
  @moduledoc "Models Polygon Edge deposit."

  use Explorer.Schema

  alias Explorer.Chain.{
    Block,
    Hash
  }

  @optional_attrs ~w(from to l1_transaction_hash l1_timestamp)a

  @required_attrs ~w(msg_id l1_block_number)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `msg_id` - id of the message
  * `from` - source address of the message
  * `to` - target address of the message
  * `l1_transaction_hash` - hash of the L1 transaction containing the corresponding StateSynced event
  * `l1_timestamp` - timestamp of the L1 transaction block
  * `l1_block_number` - block number of the L1 transaction
  """
  @type t :: %__MODULE__{
          msg_id: non_neg_integer(),
          from: Hash.Address.t() | nil,
          to: Hash.Address.t() | nil,
          l1_transaction_hash: Hash.t() | nil,
          l1_timestamp: DateTime.t() | nil,
          l1_block_number: Block.block_number()
        }

  @primary_key false
  schema "polygon_edge_deposits" do
    field(:msg_id, :integer, primary_key: true)
    field(:from, Hash.Address)
    field(:to, Hash.Address)
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_timestamp, :utc_datetime_usec)
    field(:l1_block_number, :integer)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:msg_id)
  end
end
