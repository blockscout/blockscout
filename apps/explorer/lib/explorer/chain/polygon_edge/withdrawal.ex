defmodule Explorer.Chain.PolygonEdge.Withdrawal do
  @moduledoc "Models Polygon Edge withdrawal."

  use Explorer.Schema

  alias Explorer.Chain.{
    Address,
    Block,
    Hash,
    Transaction
  }

  @optional_attrs ~w(from to)a

  @required_attrs ~w(msg_id l2_transaction_hash l2_block_number)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `msg_id` - id of the message
  * `from` - source address of the message
  * `to` - target address of the message
  * `l2_transaction_hash` - hash of the L2 transaction containing the corresponding L2StateSynced event
  * `l2_block_number` - block number of the L2 transaction
  """
  @type t :: %__MODULE__{
          msg_id: non_neg_integer(),
          from: Hash.Address.t() | nil,
          from_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          to: Hash.Address.t() | nil,
          to_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          l2_transaction_hash: Hash.t(),
          l2_transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          l2_block_number: Block.block_number(),
          l2_block: %Ecto.Association.NotLoaded{} | Block.t()
        }

  @primary_key false
  schema "polygon_edge_withdrawals" do
    field(:msg_id, :integer, primary_key: true)

    belongs_to(:from_address, Address, foreign_key: :from, references: :hash, type: Hash.Address)
    belongs_to(:to_address, Address, foreign_key: :to, references: :hash, type: Hash.Address)
    belongs_to(:l2_transaction, Transaction, foreign_key: :l2_transaction_hash, references: :hash, type: Hash.Full)
    belongs_to(:l2_block, Block, foreign_key: :l2_block_number, references: :number, type: :integer)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:msg_id)
    |> unique_constraint(:l2_transaction_hash)
  end
end
