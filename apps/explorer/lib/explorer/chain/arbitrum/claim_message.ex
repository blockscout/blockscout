defmodule Explorer.Chain.Arbitrum.ClaimMessage do
  alias Explorer.PagingOptions
  alias Explorer.Chain.Arbitrum.{L1Batch, Message, Reader}
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  #alias Explorer.Chain.Hash.Address
  #alias Explorer.Helper, as: ExplorerHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper
  alias EthereumJSONRPC
  alias ABI.TypeDecoder
  alias EthereumJSONRPC.Encoder

  Explorer.Chain.Arbitrum.Withdraw

  require Logger

  # 32-byte signature of the event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)
  @l2_to_l1_event "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc"

  # 32-byte signature of the event NodeCreated(...)
  @node_created_event "0x4f4caa9e67fb994e349dd35d1ad0ce23053d4323f83ce11dc817b5435031d096"

  @doc """
    Retrieves all L2ToL1Tx events from she specified transaction

    As per the Arbitrum rollup nature, from the indexer's point of view, a batch does not exist until
    the commitment transaction is submitted to L1. Therefore, the situation where a batch exists but
    there is no commitment transaction is not possible.

    ## Returns
    - The number of the L1 block, or `nil` if no rollup batches are found, or if the association between the batch
      and the commitment transaction has been broken due to database inconsistency.
  """
  @spec transaction_to_withdrawals(Hash.Full.t()) :: Explorer.Chain.Arbitrum.Withdraw.t() | nil
  def transaction_to_withdrawals(tx_hash) do
    #tx_hash_bin = tx_hash
    #  |> String.trim_leading("0x")
    #  |> Base.decode16!(case: :mixed)

    Chain.transaction_to_logs_by_topic0(tx_hash, @l2_to_l1_event)
      |> Enum.map(fn log ->
        # getting needed fields from the L2ToL1Tx event
        [caller, arb_block_num, eth_block_num, l2_timestamp, call_value, data] =
          TypeDecoder.decode_raw(log.data.bytes, [:address, {:uint, 256}, {:uint, 256}, {:uint, 256}, {:uint, 256}, :bytes])

          destination = case Hash.Address.cast(Hash.to_integer(log.second_topic)) do
            {:ok, address} -> address
            _ -> nil
          end

          caller = case Hash.Address.cast(caller) do
            {:ok, address} -> address
            _ -> nil
          end

          data = data
            |> Base.encode16(case: :lower)
            |> (&("0x" <> &1)).()

        %Explorer.Chain.Arbitrum.Withdraw{
          message_id: Hash.to_integer(log.fourth_topic),
          status: :unconfirmed,
          tx_hash: tx_hash,
          caller: caller,
          destination: destination,
          arb_block_num: arb_block_num,
          eth_block_num: eth_block_num,
          l2_timestamp: l2_timestamp,
          callvalue: call_value,
          data: data
        }
      end
    )
  end

end
