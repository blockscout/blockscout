defmodule Explorer.Chain.PolygonEdge.DepositExecute do
  @moduledoc "Models Polygon Edge deposit execute."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(msg_id l2_transaction_hash l2_block_number success)a

  @typedoc """
  * `msg_id` - id of the message
  * `l2_transaction_hash` - hash of the L2 transaction containing the corresponding StateSyncResult event
  * `l2_block_number` - block number of the L2 transaction
  * `success` - a status of onStateReceive internal call (namely internal deposit transaction)
  """
  @primary_key false
  typed_schema "polygon_edge_deposit_executes" do
    field(:msg_id, :integer, primary_key: true, null: false)
    field(:l2_transaction_hash, Hash.Full, null: false)
    field(:l2_block_number, :integer, null: false)
    field(:success, :boolean, null: false)

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
