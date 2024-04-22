defmodule Explorer.Chain.PolygonEdge.WithdrawalExit do
  @moduledoc "Models Polygon Edge withdrawal exit."

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}

  @required_attrs ~w(msg_id l1_transaction_hash l1_block_number success)a

  @typedoc """
  * `msg_id` - id of the message
  * `l1_transaction_hash` - hash of the L1 transaction containing the corresponding ExitProcessed event
  * `l1_block_number` - block number of the L1 transaction
  * `success` - a status of onL2StateReceive internal call (namely internal withdrawal transaction)
  """
  @primary_key false
  typed_schema "polygon_edge_withdrawal_exits" do
    field(:msg_id, :integer, primary_key: true, null: false)
    field(:l1_transaction_hash, Hash.Full, null: false)
    field(:l1_block_number, :integer) :: Block.block_number()
    field(:success, :boolean, null: false)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:msg_id)
  end
end
