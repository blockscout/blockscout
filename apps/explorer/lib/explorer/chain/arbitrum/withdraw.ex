defmodule Explorer.Chain.Arbitrum.Withdraw do
  @moduledoc """
    Models an L2->L1 withdraw on Arbitrum.

  """

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(message_id status tx_hash caller destination arb_block_num eth_block_num l2_timestamp callvalue data)a


  @typedoc """
  Descriptor of the L2ToL1Tx event message on Arbitrum rollups:
    * `message_id` - The ID of the message used for referencing.
    * `status` - The status of the withdrawal: `:unconfirmed`, `:confirmed`, `:executed`
    * `tx_hash` - The transaction (L2 chain) hash which emit this event
    * `caller` - The sender of the withdraw transaction.
    * `destination` - The receiver of the funds on L1 chain.
    * `arb_block_num` - The number of the block where originating transaction is included.
    * `eth_block_num` - The associated block number on the destination chain.
    * `l2_timestamp` - The timestamp of the originating transaction.
    * `callvalue` - The amount of the native coins to withdraw
    * `data` - Raw transaction data which will be sent to the destination address on L1 chain
               on claiming the withdraw. In that case sestination should be a contract adress
               otherwise the transaction will fail. Typicaly this field contain calldata for
               `finalizeInboundTransfer(address,address,address,uint256,bytes)` method of the
               Bridge contract and it intended to withdraw supported tokens instead of native coins.
  """
  @type to_import :: %{
          message_id: non_neg_integer(),
          status: :unconfirmed | :confirmed | :executed,
          tx_hash: binary(),
          caller: binary(),
          destination: binary(),
          arb_block_num: non_neg_integer(),
          eth_block_num: non_neg_integer(),
          l2_timestamp: non_neg_integer(),
          callvalue: non_neg_integer(),
          data: binary(),
        }

  @typedoc """
  Descriptor of the L2ToL1Tx event message on Arbitrum rollups:
    * `message_id` - The ID of the message used for referencing.
    * `status` - The status of the withdrawal: `:unconfirmed`, `:confirmed`, `:executed`
    * `tx_hash` - The transaction (L2 chain) hash which emit this event
    * `caller` - The sender of the withdraw transaction.
    * `destination` - The receiver of the funds on L1 chain.
    * `arb_block_num` - The number of the block where originating transaction is included.
    * `eth_block_num` - The associated block number on the destination chain.
    * `l2_timestamp` - The timestamp of the originating transaction.
    * `callvalue` - The amount of the native coins to withdraw
    * `data` - Raw transaction data which will be sent to the destination address on L1 chain
               on claiming the withdraw. In that case sestination should be a contract adress
               otherwise the transaction will fail. Typicaly this field contain calldata for
               `finalizeInboundTransfer(address,address,address,uint256,bytes)` method of the
               Bridge contract and it intended to withdraw supported tokens instead of native coins.
  """
  @primary_key false
  typed_schema "arbitrum_withdraw" do
    field(:message_id, :integer, primary_key: true)
    field(:status, Ecto.Enum, values: [:unconfirmed, :confirmed, :executed])
    field(:tx_hash, Hash.Full)
    field(:caller, Hash.Address)
    field(:destination, Hash.Address)
    field(:arb_block_num, :integer)
    field(:eth_block_num, :integer)
    field(:l2_timestamp, :integer)
    field(:callvalue, :integer)
    field(:data, :binary)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = txn, attrs \\ %{}) do
    txn
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:direction, :message_id])
  end
end
