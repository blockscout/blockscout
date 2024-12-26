defmodule Explorer.Arbitrum.Withdraw do
  @moduledoc """
    Models an L2->L1 withdraw on Arbitrum.

  """

  alias Explorer.Chain.Hash

  @typedoc """
  Descriptor of the L2ToL1Tx event message on Arbitrum rollups:
    * `message_id` - The ID of the message used for referencing.
    * `status` - The status of the withdrawal: `:unknown`, `:initiated`, `:sent`, `:confirmed`, `:relayed`
    * `caller` - The sender of the withdraw transaction.
    * `destination` - The receiver of the funds on L1 chain.
    * `arb_block_number` - The number of the block where originating transaction is included.
    * `eth_block_number` - The associated block number on the destination chain.
    * `l2_timestamp` - The timestamp of the originating transaction.
    * `callvalue` - The amount of the native coins to withdraw
    * `data` - Raw transaction data which will be sent to the destination address on L1 chain
               on claiming the withdraw. In that case destination should be a contract address
               otherwise the transaction will fail. Typically this field contain calldata for
               `finalizeInboundTransfer(address,address,address,uint256,bytes)` method of the
               Bridge contract and it intended to withdraw supported tokens instead of native coins.
    * `token_address` - extracted address of the token to withdraw in case of `data` field represents Bridge transaction
    * `token_destination` - extracted receiver address in case of `data` field represents Bridge transaction
    * `token_amount` - extracted token amount in case of `data` field represents Bridge transaction
  """

  @type t :: %__MODULE__{
          message_id: message_id,
          status: status,
          caller: caller,
          destination: destination,
          arb_block_number: arb_block_number,
          eth_block_number: eth_block_number,
          l2_timestamp: l2_timestamp,
          callvalue: callvalue,
          data: data,
          token:
            %{
              address: token_address,
              destination: token_destination,
              amount: token_amount
            }
            | nil
        }

  @typep message_id :: non_neg_integer()
  @typep status :: :unknown | :initiated | :sent | :confirmed | :relayed
  @typep caller :: Hash.Address.t()
  @typep destination :: Hash.Address.t()
  @typep arb_block_number :: non_neg_integer()
  @typep eth_block_number :: non_neg_integer()
  @typep l2_timestamp :: non_neg_integer()
  @typep callvalue :: non_neg_integer()
  @typep data :: binary()
  @typep token_address :: Hash.Address.t()
  @typep token_destination :: Hash.Address.t()
  @typep token_amount :: non_neg_integer()

  defstruct [
    :message_id,
    :status,
    :caller,
    :destination,
    :arb_block_number,
    :eth_block_number,
    :l2_timestamp,
    :callvalue,
    :data,
    token: nil
  ]
end
