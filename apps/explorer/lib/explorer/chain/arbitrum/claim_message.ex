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

    In the most cases the transaction initiates a single L2->L1 message.
    But in general the transaction can include several messages

    ## Parameters
    - `tx_hash`: The transaction hash which will scanned for L2ToL1Tx events.

    ## Returns
    - Array of `Explorer.Chain.Arbitrum.Withdraw.t()` objects each of them represent
      a single message originated by the given transaction.
  """
  @spec transaction_to_withdrawals(Hash.Full.t()) :: [Explorer.Chain.Arbitrum.Withdraw.t()]
  def transaction_to_withdrawals(tx_hash) do
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

  @doc """
    Construct calldata for claiming L2->L1 message on L1 chain

    To claim a message on L1 user should use method of th Outbox smart contract:
    `executeTransaction(proof, index, l2Sender, to, l2Block, l1Block, l2Timestamp, value, data)`
    The first parameter, outbox proof should be calculated separetely with NodeInterface's
    method `constructOutboxProof(size, leaf)`.

    ## Parameters
    - `message_id`: `position` field of the associated `L2ToL1Tx` event.

    ## Returns
    - `{:ok, [contract_address: Explorer.Chain.Hash.Address, calldata: String]}` | `{:error, _}`
      where `contract_address` - the address where claim transaction should be sent (Outbox on L1),
            `calldata` - transaction raw calldata starting with selector
  """
  @spec claim(non_neg_integer()) :: Explorer.Chain.Arbitrum.Withdraw.t() | nil
  def claim(message_id) do
    case Reader.l2_to_l1_message_with_id(message_id) do
      msg ->
        #Logger.warning("Received message #{inspect(msg)}")

        case transaction_to_withdrawals(msg.originating_transaction_hash)
          |> Enum.filter(fn w -> w.message_id == message_id end)
          |> List.first()
        do
            withdrawal ->
              Logger.warning("OK")

            nil -> {:error, :not_found}
        end

        nil -> {:error, :not_found}
    end
  end

  @spec get_size_for_proof(non_neg_integer()) :: non_neg_integer()
  defp get_size_for_proof() do
    # getting needed L1 properties: RPC URL and Main Rollup contract address
    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    l1_rpc = config_common[:l1_rpc]
    json_l1_rpc_named_arguments = IndexerHelper.json_rpc_named_arguments(l1_rpc)
    json_l2_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    l1_rollup_address = config_common[:l1_rollup_address]
    node_interface_address = "0x00000000000000000000000000000000000000c8"
    outbox_contract = Rpc.get_contracts_for_rollup(l1_rollup_address, :inbox_outbox, json_l1_rpc_named_arguments)[:outbox]

    Logger.warning("Outbox contract: #{outbox_contract}")

    #Logger.warning("l1_rollup_address: #{inspect(l1_rollup_address, pretty: true)}")
    #Logger.warning("json_rpc_named_arguments: #{inspect(json_rpc, pretty: true)}")
    #Logger.warning("Application.get_all_env(:indexer): #{inspect(Application.get_all_env(:indexer), pretty: true)}")
    #Logger.warning("config_common: #{inspect(config_common, pretty: true)}")

    # getting latest confirmed node index (L1)
    latest_confirmed = Rpc.get_latest_confirmed_l2_to_l1_message_id(
      l1_rollup_address,
      json_l1_rpc_named_arguments
    )

    # getting block number (L1) where latest confirmed node was created
    node_creation_block_num = case Rpc.get_node(l1_rollup_address, latest_confirmed, json_l1_rpc_named_arguments) do
      [{:ok, [fields]}] -> Kernel.elem(fields, 10)
      [{:error, _}] -> nil
    end

    # request NodeCreated event from that block
    node_created_event = case IndexerHelper.get_logs(
      node_creation_block_num,
      node_creation_block_num,
      l1_rollup_address,
      [@node_created_event],
      json_l1_rpc_named_arguments
    ) do
      {:ok, logs} -> logs |> List.first()
      {:errorr, _} -> nil
    end

    #Logger.warning("NodeCreated event: #{inspect(node_created_event, pretty: true)}")

    [_execution_hash, {_, {{[l2_block_hash, _], _, }, _}, _}, _after_inbox_batch_acc, _wasm_module_root, _inbox_max_count] =
      node_created_event
      |> Map.get("data")
      |> String.trim_leading("0x")
      |> Base.decode16!(case: :mixed)
      |> TypeDecoder.decode_raw([
        {:bytes, 32},
        {:tuple, [  # Asserion asserion
          {:tuple, [ # ExecutionState beforeState
            {:tuple, [ # GlobalState globalState
              {:array, {:bytes, 32}, 2},  # bytes32[2] bytes32Vals
              {:array, {:uint, 64}, 2},  # uint64[2] u64Vals
            ]},
            {:uint, 256}  # MachineStatus machineStatus: enum MachineStatus {RUNNING, FINISHED, ERRORED, TOO_FAR}
          ]},
          {:tuple, [ # ExecutionState afterState
            {:tuple, [ # GlobalState globalState
              {:array, {:bytes, 32}, 2},  # bytes32[2] bytes32Vals
              {:array, {:uint, 64}, 2},  # uint64[2] u64Vals
            ]},
            {:uint, 256}  # MachineStatus machineStatus: enum MachineStatus {RUNNING, FINISHED, ERRORED, TOO_FAR}
          ]},
          {:uint, 64} # uint64 numBlocks
        ]},
        {:bytes, 32},
        {:bytes, 32},
        {:uint, 256}
      ])
    {:ok, l2_block_hash} = l2_block_hash
      |> Hash.Full.cast()

    Logger.warning("L2 hash: #{Hash.to_string(l2_block_hash)}")

    # getting L2 block with that hash
    l2_block_send_count = case Chain.hash_to_block(l2_block_hash) do
      {:ok, block} -> block.send_count
      {:error, _} ->
        case EthereumJSONRPC.fetch_blocks_by_hash([l2_block_hash], json_l2_rpc_named_arguments, false) do
          {:ok, blocks} -> blocks.blocks_params
            |> hd()
            |> Map.get(:send_count)

          {:error, _} ->
            Logger.error("failed to fetch block by hash #{l2_block_hash}")
            nil
        end
    end

    Logger.warning("size for outbox proof: #{inspect(l2_block_send_count, pretty: true)}")

    l2_block_send_count
  end

end
