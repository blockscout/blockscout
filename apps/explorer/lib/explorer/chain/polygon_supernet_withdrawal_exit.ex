defmodule Explorer.Chain.PolygonSupernetWithdrawalExit do
  @moduledoc "Models polygon supernet withdrawal exit."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(msg_id l1_transaction_hash l1_block_number success)a

  @typedoc """
  * `msg_id` - id of the message
  * `l1_transaction_hash` - hash of the L1 transaction containing the corresponding ExitProcessed event
  * `l1_block_number` - block number of the L1 transaction
  * `success` - a status of onL2StateReceive internal call (namely internal withdrawal transaction)
  """
  @type t :: %__MODULE__{
          msg_id: non_neg_integer(),
          l1_transaction_hash: Hash.t(),
          l1_block_number: Block.block_number(),
          success: boolean()
        }

  @primary_key false
  schema "polygon_supernet_withdrawal_exits" do
    field(:msg_id, :integer, primary_key: true)
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_block_number, :integer)
    field(:success, :boolean)

    timestamps()
  end

  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:msg_id)
  end
end
