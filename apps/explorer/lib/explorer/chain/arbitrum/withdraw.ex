defmodule Explorer.Chain.Arbitrum.Withdraw do
  @moduledoc """
    Models an L2->L1 withdraw on Arbitrum.

  """

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @optional_attrs ~w(token_address token_destination token_amount)a

  @required_attrs ~w(message_id status tx_hash caller destination arb_block_num eth_block_num l2_timestamp callvalue data)a

  @allowed_attrs @optional_attrs ++ @required_attrs


  @typedoc """
  Descriptor of the L2ToL1Tx event message on Arbitrum rollups:
    * `message_id` - The ID of the message used for referencing.
    * `status` - The status of the withdrawal: `:unknown`, `:unconfirmed`, `:confirmed`, `:executed`
    * `tx_hash` - The transaction (L2 chain) hash which emit this event
    * `caller` - The sender of the withdraw transaction.
    * `destination` - The receiver of the funds on L1 chain.
    * `arb_block_num` - The number of the block where originating transaction is included.
    * `eth_block_num` - The associated block number on the destination chain.
    * `l2_timestamp` - The timestamp of the originating transaction.
    * `callvalue` - The amount of the native coins to withdraw
    * `data` - Raw transaction data which will be sent to the destination address on L1 chain
               on claiming the withdraw. In that case destination should be a contract adress
               otherwise the transaction will fail. Typicaly this field contain calldata for
               `finalizeInboundTransfer(address,address,address,uint256,bytes)` method of the
               Bridge contract and it intended to withdraw supported tokens instead of native coins.
    `token_address` - extracted address of the token to withdraw in case of `data` field represents Bridge transaction
    `token_destination` - extracted receiver address in case of `data` field represents Bridge transaction
    `token_amount` - extracted token amount in case of `data` field represents Bridge transaction
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
          token_address: binary(),
          token_destination: binary(),
          token_amount: non_neg_integer()
        }

  @typedoc """
  Descriptor of the L2ToL1Tx event message on Arbitrum rollups:
    * `message_id` - The ID of the message used for referencing.
    * `status` - The status of the withdrawal: `:unknown`, `:unconfirmed`, `:confirmed`, `:executed`
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
    `token_address` - extracted address of the token to withdraw in case of `data` field represents Bridge transaction
    `token_destination` - extracted receiver address in case of `data` field represents Bridge transaction
    `token_amount` - extracted token amount in case of `data` field represents Bridge transaction
  """
  @primary_key {:message_id, :integer, autogenerate: false}
  typed_schema "arbitrum_withdraw" do
    field(:status, Ecto.Enum, values: [:unconfirmed, :confirmed, :executed])
    field(:tx_hash, Hash.Full)
    field(:caller, Hash.Address)
    field(:destination, Hash.Address)
    field(:arb_block_num, :integer)
    field(:eth_block_num, :integer)
    field(:l2_timestamp, :integer)
    field(:callvalue, :integer)
    field(:data, :binary)
    field(:token_address, Hash.Address)
    field(:token_destination, Hash.Address)
    field(:token_amount, :integer)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = txn, attrs \\ %{}) do
    txn
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:message_id])
  end
end
