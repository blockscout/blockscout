defmodule Explorer.Arbitrum.ClaimRollupMessage do
  @moduledoc """
  The module is responsible for getting withdrawal list from the Arbitrum transaction.
  The associated transaction should emit at least one `L2ToL1Tx` event  which means
  the L2 -> L1 message was initiated.

  Also it helps to generate calldata for `executeTransaction` method of the `Outbox`
  contact deployed on L1 to finalize initiated withdrawal

  The details of L2-to-L1 messaging can be found in the following link:
  https://docs.arbitrum.io/how-arbitrum-works/arbos/l2-l1-messaging
  """

  alias ABI.TypeDecoder
  alias EthereumJSONRPC
  alias EthereumJSONRPC.Arbitrum, as: ArbitrumRpc
  alias EthereumJSONRPC.Encoder
  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum.Reader, as: ArbitrumReader
  alias Explorer.Chain.{Data, Hash}
  alias Explorer.Chain.Hash.Address
  alias Indexer.Helper, as: IndexerHelper

  require Logger

  # 32-byte signature of the event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)
  @l2_to_l1_event "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc"

  # 32-byte signature of the event NodeCreated(...)
  @node_created_event "0x4f4caa9e67fb994e349dd35d1ad0ce23053d4323f83ce11dc817b5435031d096"

  # Address of precompile NodeInterface precompile [L2]
  @node_interface_address "0x00000000000000000000000000000000000000c8"

  @node_created_data_abi [
    {:bytes, 32},
    # Assertion assertion
    {:tuple,
     [
       # ExecutionState beforeState
       {:tuple,
        [
          # GlobalState globalState
          {:tuple,
           [
             # bytes32[2] bytes32Values
             {:array, {:bytes, 32}, 2},
             # uint64[2] u64Values
             {:array, {:uint, 64}, 2}
           ]},
          # MachineStatus machineStatus: enum MachineStatus {RUNNING, FINISHED, ERRORED, TOO_FAR}
          {:uint, 256}
        ]},
       # ExecutionState afterState
       {:tuple,
        [
          # GlobalState globalState
          {:tuple,
           [
             # bytes32[2] bytes32Values
             {:array, {:bytes, 32}, 2},
             # uint64[2] u64Values
             {:array, {:uint, 64}, 2}
           ]},
          # MachineStatus machineStatus: enum MachineStatus {RUNNING, FINISHED, ERRORED, TOO_FAR}
          {:uint, 256}
        ]},
       # uint64 numBlocks
       {:uint, 64}
     ]},
    {:bytes, 32},
    {:bytes, 32},
    {:uint, 256}
  ]

  @finalize_inbound_transfer_selector %ABI.FunctionSelector{
    function: "finalizeInboundTransfer",
    returns: [],
    types: [
      # _token
      :address,
      # _from
      :address,
      # _to
      :address,
      # _amount
      {:uint, 256},
      # data
      :bytes
    ]
  }

  @execute_transaction_selector %ABI.FunctionSelector{
    function: "executeTransaction",
    returns: [],
    types: [
      # proof
      {:array, {:bytes, 32}},
      # index
      {:uint, 256},
      # l2Sender
      :address,
      # to
      :address,
      # l2Block
      {:uint, 256},
      # l1Block
      {:uint, 256},
      # l2Timestamp
      {:uint, 256},
      # value
      {:uint, 256},
      # data
      :bytes
    ],
    type: :function,
    inputs_indexed: []
  }

  @doc """
    Retrieves all L2ToL1Tx events from she specified transaction and convert them to the withdrawals

    In the most cases the transaction initiates a single L2->L1 message.
    But in general the transaction can include several messages

    ## Parameters
    - `transaction_hash`: The transaction hash which will scanned for L2ToL1Tx events.

    ## Returns
    - Array of `Explorer.Arbitrum.Withdraw.t()` objects each of them represent
      a single message originated by the given transaction.
  """
  @spec transaction_to_withdrawals(Hash.Full.t()) :: [Explorer.Arbitrum.Withdraw.t()]
  def transaction_to_withdrawals(transaction_hash) do
    # request messages initiated by the provided transaction from the database
    messages = ArbitrumReader.l2_to_l1_messages_by_transaction_hash(transaction_hash, api?: true)

    # request associated logs from the database
    logs = ArbitrumReader.transaction_to_logs_by_topic0(transaction_hash, @l2_to_l1_event)

    logs
    |> Enum.map(fn log ->
      msg = Enum.find(messages, fn msg -> msg.message_id == Hash.to_integer(log.fourth_topic) end)
      # The way to convert log to `Withdrawal` depends on the presence of the associated message
      log_to_withdrawal(log, msg)
    end)
  end

  @doc """
    Construct calldata for claiming L2->L1 message on L1 chain

    To claim a message on L1 user should use method of th Outbox smart contract:
    `executeTransaction(proof, index, l2Sender, to, l2Block, l1Block, l2Timestamp, value, data)`
    The first parameter, outbox proof should be calculated separately with NodeInterface's
    method `constructOutboxProof(size, leaf)`.

    ## Parameters
    - `message_id`: `position` field of the associated `L2ToL1Tx` event.

    ## Returns
    - `{:ok, [contract_address: String, calldata: String]}` | `{:error, _}`
      where `contract_address` - the address where claim transaction should be sent (Outbox on L1),
            `calldata` - transaction raw calldata starting with selector
  """
  @spec claim(non_neg_integer()) :: {:ok, [contract_address: String.t(), calldata: String.t()]} | {:error, term()}
  def claim(message_id) do
    case ArbitrumReader.l2_to_l1_message_with_id(message_id, api?: true) do
      nil ->
        Logger.error("Unable to find withdrawal with id #{message_id}")
        {:error, :not_found}

      message ->
        claim_message(message)
    end
  end

  # Construct a claim transaction calldata based on the provided message
  @spec claim_message(Explorer.Chain.Arbitrum.Message.t()) ::
          {:ok, list({:contract_address, binary()} | {:calldata, binary()})}
          | {:error, term()}
  defp claim_message(message) do
    # request associated log from the database
    case message.originating_transaction_hash
         |> ArbitrumReader.transaction_to_logs_by_topic0(@l2_to_l1_event)
         |> Enum.find(fn log -> Hash.to_integer(log.fourth_topic) == message.message_id end) do
      nil ->
        Logger.error("Unable to find log with message_id #{message.message_id}")
        {:error, :not_found}

      log ->
        case log_to_withdrawal(log, message) do
          nil ->
            Logger.error(
              "Unable to find withdrawal with id #{message.message_id} in transaction #{Hash.to_string(message.originating_transaction_hash)}"
            )

            {:error, :not_found}

          withdrawal when withdrawal.status == :confirmed ->
            construct_claim(withdrawal)

          w when w.status == :initiated ->
            {:error, :initiated}

          w when w.status == :sent ->
            {:error, :sent}

          w when w.status == :relayed ->
            {:error, :relayed}
        end
    end
  end

  # Convert `Explorer.Chain.Arbitrum.Message.t()` with an associated L2ToL1Tx event data
  # (`Explorer.Chain.Log.t()`) to the `Explorer.Arbitrum.Withdraw.t()` structure
  # We need associated event to extract additional fields which are not reflected in the database message
  # The method doesn't request additional data from the RPC or DB, it just parses the provided structures
  @spec log_to_withdrawal(
          Explorer.Chain.Log.t(),
          Explorer.Chain.Arbitrum.Message.t() | nil
        ) :: Explorer.Arbitrum.Withdraw.t() | nil

  defp log_to_withdrawal(log, nil) do
    log_to_withdraw(log)
  end

  defp log_to_withdrawal(log, message) do
    # getting needed fields from the L2ToL1Tx event
    fields =
      log
      |> convert_explorer_log_to_map()
      |> ArbitrumRpc.l2_to_l1_event_parse()

    if fields.message_id == message.message_id do
      # extract token withdrawal info from the associated event's data
      token = decode_withdraw_token_data(fields.data)

      data_hex =
        fields.data
        |> Base.encode16(case: :lower)

      {:ok, caller_address} = Hash.Address.cast(fields.caller)
      {:ok, destination_address} = Hash.Address.cast(fields.destination)

      %Explorer.Arbitrum.Withdraw{
        message_id: Hash.to_integer(log.fourth_topic),
        status: message.status,
        caller: caller_address,
        destination: destination_address,
        arb_block_number: fields.arb_block_number,
        eth_block_number: fields.eth_block_number,
        l2_timestamp: fields.timestamp,
        callvalue: fields.callvalue,
        data: "0x" <> data_hex,
        token: token
      }
    else
      Logger.error(
        "message_to_withdrawal: log doesn't correspond message (#{fields.position} != #{message.message_id})"
      )

      nil
    end
  end

  # Convert L2ToL1Tx event to the internal structure describing L2->L1 withdrawal.
  # To get all required fields the method uses RPC calls to the L1 and L2 nodes.
  @spec log_to_withdraw(Explorer.Chain.Log.t()) :: Explorer.Arbitrum.Withdraw.t()
  defp log_to_withdraw(log) do
    # getting needed L1\L2 properties: RPC URL and Main Rollup contract address
    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    json_l1_rpc_named_arguments = IndexerHelper.json_rpc_named_arguments(config_common[:l1_rpc])
    json_l2_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    l1_rollup_address = config_common[:l1_rollup_address]

    outbox_contract =
      ArbitrumRpc.get_contracts_for_rollup(l1_rollup_address, :inbox_outbox, json_l1_rpc_named_arguments)[:outbox]

    # getting needed fields from the L2ToL1Tx event
    # {position, caller, destination, arb_block_number, eth_block_number, l2_timestamp, call_value, data} =
    fields =
      log
      |> convert_explorer_log_to_map()
      |> ArbitrumRpc.l2_to_l1_event_parse()

    {:ok, is_withdrawal_spent} =
      ArbitrumRpc.withdrawal_spent?(outbox_contract, fields.message_id, json_l1_rpc_named_arguments)

    status =
      case is_withdrawal_spent do
        true ->
          :relayed

        false ->
          case get_size_for_proof_from_rpc(l1_rollup_address, json_l1_rpc_named_arguments, json_l2_rpc_named_arguments) do
            nil -> :unknown
            size when size > fields.message_id -> :confirmed
            _ -> :sent
          end
      end

    token = decode_withdraw_token_data(fields.data)

    data_hex =
      fields.data
      |> Base.encode16(case: :lower)

    {:ok, caller_address} = Hash.Address.cast(fields.caller)
    {:ok, destination_address} = Hash.Address.cast(fields.destination)

    %Explorer.Arbitrum.Withdraw{
      message_id: Hash.to_integer(log.fourth_topic),
      status: status,
      caller: caller_address,
      destination: destination_address,
      arb_block_number: fields.arb_block_number,
      eth_block_number: fields.eth_block_number,
      l2_timestamp: fields.timestamp,
      callvalue: fields.callvalue,
      data: "0x" <> data_hex,
      token: token
    }
  end

  # Internal routine used to convert `Explorer.Chain.Log.t()` structure
  # into the `EthereumJSONRPC.Arbitrum.event_data()` type. It's needed
  # to call `EthereumJSONRPC.Arbitrum.l2_to_l1_event_parse(event_data)` method
  @spec convert_explorer_log_to_map(Explorer.Chain.Log.t()) :: %{
          :data => binary(),
          :second_topic => binary(),
          :fourth_topic => binary()
        }
  defp convert_explorer_log_to_map(log) do
    %{
      :data => Data.to_string(log.data),
      :second_topic => Hash.to_string(log.second_topic),
      :fourth_topic => Hash.to_string(log.fourth_topic)
    }
  end

  # Internal routine used to extract needed fields from the `finalizeInboundTransfer(...)` calldata.
  # This calldata encapsulated into the L2ToL1Tx event and supposed to be executed on the TokenBridge contract
  # during the withdraw claiming. It used here to obtain tokens withdraw info from the associated event.
  # The function returns the token address, destination address, and amount of the token to withdraw
  # In case of the provided data is void or it doesn't correspond to the `finalizeInboundTransfer` method
  # `nil` will be returned
  @spec decode_withdraw_token_data(binary()) ::
          %{
            address: Explorer.Chain.Hash.Address.t(),
            destination: Explorer.Chain.Hash.Address.t(),
            amount: non_neg_integer()
          }
          | nil
  defp decode_withdraw_token_data(<<0x2E567B36::32, rest_data::binary>>) do
    [token, _, to, amount, _] = ABI.decode(@finalize_inbound_transfer_selector, rest_data)

    token_bin =
      case Address.cast(token) do
        {:ok, address} -> address
        _ -> nil
      end

    to_bin =
      case Address.cast(to) do
        {:ok, address} -> address
        _ -> nil
      end

    %{
      address: token_bin,
      destination: to_bin,
      amount: amount
    }
  end

  defp decode_withdraw_token_data(_binary) do
    nil
  end

  # Builds a claim transaction calldata based on extended withdraw info
  @spec construct_claim(Explorer.Arbitrum.Withdraw.t()) ::
          {:ok, [contract_address: binary(), calldata: binary()]} | {:error, :internal_error}
  defp construct_claim(withdrawal) do
    # getting needed L1 properties: RPC URL and Main Rollup contract address
    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    l1_rpc = config_common[:l1_rpc]
    json_l1_rpc_named_arguments = IndexerHelper.json_rpc_named_arguments(l1_rpc)
    json_l2_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    l1_rollup_address = config_common[:l1_rollup_address]

    outbox_contract =
      ArbitrumRpc.get_contracts_for_rollup(l1_rollup_address, :inbox_outbox, json_l1_rpc_named_arguments)[:outbox]

    size_for_proof =
      case get_size_for_proof_from_database() do
        nil ->
          Logger.warning(
            "The database doesn't contain required data to construct proof. Fallback to direct RPC request"
          )

          get_size_for_proof_from_rpc(l1_rollup_address, json_l1_rpc_named_arguments, json_l2_rpc_named_arguments)

        size ->
          size
      end

    case size_for_proof do
      nil ->
        Logger.error("Cannot get size for proof")
        {:error, :internal_error}

      size ->
        # now we are ready to construct outbox proof
        case ArbitrumRpc.construct_outbox_proof(
               @node_interface_address,
               size,
               withdrawal.message_id,
               json_l2_rpc_named_arguments
             ) do
          {:ok, [_send, _root, proof]} ->
            proof_values = raw_proof_to_hex(proof)

            # finally encode function call
            args = [
              proof_values,
              withdrawal.message_id,
              Hash.to_string(withdrawal.caller),
              Hash.to_string(withdrawal.destination),
              withdrawal.arb_block_number,
              withdrawal.eth_block_number,
              withdrawal.l2_timestamp,
              withdrawal.callvalue,
              withdrawal.data
            ]

            calldata = Encoder.encode_function_call(@execute_transaction_selector, args)

            {:ok, [contract_address: outbox_contract, calldata: calldata]}

          {:error, _} ->
            Logger.error("Unable to construct proof with size = #{size}, leaf = #{withdrawal.message_id}")

            {:error, :internal_error}
        end
    end
  end

  # Converts list of binaries into the hex-encoded 0x-prefixed strings
  defp raw_proof_to_hex(proof) do
    proof
    |> Enum.map(fn p -> "0x" <> Base.encode16(p, case: :lower) end)
  end

  # Retrieving `size` parameter needed to construct outbox proof
  # using the data from the local database
  @spec get_size_for_proof_from_database() :: non_neg_integer() | nil
  defp get_size_for_proof_from_database do
    case ArbitrumReader.highest_confirmed_block() do
      nil ->
        nil

      highest_confirmed_block ->
        case Chain.number_to_block(highest_confirmed_block) do
          {:ok, block} -> Map.get(block, :send_count)
          _ -> nil
        end
    end
  end

  # Retrieving `size` parameter needed to construct outbox proof using the RPC node
  # this method is based on direct RPC requests to retrieve an actual withdrawals count
  @spec get_size_for_proof_from_rpc(
          String.t(),
          EthereumJSONRPC.json_rpc_named_arguments(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: non_neg_integer() | nil
  defp get_size_for_proof_from_rpc(l1_rollup_address, json_l1_rpc_named_arguments, json_l2_rpc_named_arguments) do
    # getting latest confirmed node index (L1) from the database
    {:ok, latest_confirmed_node_index} =
      ArbitrumRpc.get_latest_confirmed_node_index(
        l1_rollup_address,
        json_l1_rpc_named_arguments
      )

    # getting L1 block number where that node was created
    case ArbitrumRpc.get_node_creation_block_number(
           l1_rollup_address,
           latest_confirmed_node_index,
           json_l1_rpc_named_arguments
         ) do
      {:ok, node_creation_l1_block_number} ->
        # getting associated L2 block and extracting `send_count` value from it
        l1_block_number_to_withdrawals_count(
          node_creation_l1_block_number,
          l1_rollup_address,
          json_l1_rpc_named_arguments,
          json_l2_rpc_named_arguments
        )

      {:error, error} ->
        Logger.error("Cannot fetch node creation block number: #{inspect(error)}")
        nil
    end
  end

  # Retrieve amount of L2->L1 messages sent up to the given L1 block
  # The requested L1 block must contain the NodeCreated event emitted by the Rollup contract
  @spec l1_block_number_to_withdrawals_count(
          non_neg_integer(),
          String.t(),
          list(),
          list()
        ) :: non_neg_integer() | nil
  defp l1_block_number_to_withdrawals_count(
         node_creation_l1_block_number,
         l1_rollup_address,
         json_l1_rpc_named_arguments,
         json_l2_rpc_named_arguments
       ) do
    # request NodeCreated event from L1 block emitted by the Rollup contract
    case IndexerHelper.get_logs(
           node_creation_l1_block_number,
           node_creation_l1_block_number,
           l1_rollup_address,
           [@node_created_event],
           json_l1_rpc_named_arguments
         ) do
      {:ok, [node_created_event]} ->
        # extract L2 block hash from the NodeCreated event
        l2_block_hash = l2_block_hash_from_node_created_event(node_created_event)

        {:ok, l2_block_hash} =
          l2_block_hash
          |> Hash.Full.cast()

        # get `send_count` value from the L2 block which represents amount of L2->L1 messages sent up to this block
        messages_count_up_to_block_with_hash(l2_block_hash, json_l2_rpc_named_arguments)

      _ ->
        Logger.error("Cannot fetch NodeCreated event in L1 block #{node_creation_l1_block_number}")
        nil
    end
  end

  # Find a L2 block by a given block's hash and extract `send_count` value
  # `send_count` field represents amount of L2->L1 messages sent up to this block
  @spec messages_count_up_to_block_with_hash(Hash.Full.t(), list()) :: non_neg_integer()
  defp messages_count_up_to_block_with_hash(l2_block_hash, json_l2_rpc_named_arguments) do
    case Chain.hash_to_block(l2_block_hash, api?: true) do
      {:ok, block} ->
        Map.get(block, :send_count)

      {:error, _} ->
        case EthereumJSONRPC.fetch_blocks_by_hash(
               [Hash.to_string(l2_block_hash)],
               json_l2_rpc_named_arguments,
               false
             ) do
          {:ok, blocks} ->
            blocks.blocks_params
            |> hd()
            |> Map.get(:send_count)

          {:error, error} ->
            Logger.error("Failed to fetch L2 block by hash #{l2_block_hash}: #{inspect(error)}")
            nil
        end
    end
  end

  # When NodeCreated event emitted on L1 main rollup contract
  # it contains associated L2 block hash.
  # The following method extracts this hash from the NodeCreated event
  @spec l2_block_hash_from_node_created_event(%{data: binary()}) :: binary()
  defp l2_block_hash_from_node_created_event(event) do
    [
      _execution_hash,
      {_, {{[l2_block_hash, _], _}, _}, _},
      _after_inbox_batch_acc,
      _wasm_module_root,
      _inbox_max_count
    ] =
      event
      |> Map.get("data")
      |> String.trim_leading("0x")
      |> Base.decode16!(case: :mixed)
      |> TypeDecoder.decode_raw(@node_created_data_abi)

    l2_block_hash
  end
end
