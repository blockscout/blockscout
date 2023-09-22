defmodule Explorer.Chain.PolygonEdge.DepositExecute do
  @moduledoc "Models Polygon Edge deposit execute."

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}

  @required_attrs ~w(msg_id l2_transaction_hash l2_block_number success)a

  @typedoc """
  * `msg_id` - id of the message
  * `l2_transaction_hash` - hash of the L2 transaction containing the corresponding StateSyncResult event
  * `l2_block_number` - block number of the L2 transaction
  * `success` - a status of onStateReceive internal call (namely internal deposit transaction)
  """
  @type t :: %__MODULE__{
          msg_id: non_neg_integer(),
          l2_transaction_hash: Hash.t(),
          l2_block_number: Block.block_number(),
          success: boolean()
        }

  @primary_key false
  schema "polygon_edge_deposit_executes" do
    field(:msg_id, :integer, primary_key: true)
    field(:l2_transaction_hash, Hash.Full)
    field(:l2_block_number, :integer)
    field(:success, :boolean)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:msg_id)
    |> unique_constraint(:l2_transaction_hash)
  end
end
