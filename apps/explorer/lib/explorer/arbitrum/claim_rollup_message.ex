defmodule Explorer.Arbitrum.ClaimRollupMessage do
  @moduledoc """
    Provides functionality to read L2->L1 messages and prepare withdrawal claims in the Arbitrum protocol.

    This module allows:
    - Retrieving L2->L1 messages from a transaction's logs and determining their current
      status. This is used when a user has a transaction hash and needs to identify
      which messages from this transaction can be claimed on L1.
    - Generating calldata for claiming confirmed withdrawals through the L1 Outbox
      contract using a specific message ID. This is typically used when the message ID
      is already known (e.g., from transaction details or L2->L1 messages list in the UI).

    For detailed information about Arbitrum's L2->L1 messaging system, see:
  https://docs.arbitrum.io/how-arbitrum-works/arbos/l2-l1-messaging
  """

  alias ABI.TypeDecoder
  alias EthereumJSONRPC
  alias EthereumJSONRPC.Arbitrum, as: ArbitrumRpc
  alias EthereumJSONRPC.Arbitrum.Constants.Contracts, as: ArbitrumContracts
  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
  alias EthereumJSONRPC.{Encoder, ERC20}
  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum.Reader.API.General, as: GeneralReader
  alias Explorer.Chain.Arbitrum.Reader.API.Messages, as: MessagesReader
  alias Explorer.Chain.Arbitrum.Reader.API.Settlement, as: SettlementReader
  alias Explorer.Chain.Arbitrum.Reader.Indexer.Messages, as: MessagesIndexerReader
  alias Explorer.Chain.{Data, Hash}
  alias Explorer.Chain.Hash.Address
  alias Indexer.Helper, as: IndexerHelper

  require Logger

  @doc """
    Retrieves all L2->L1 messages initiated by a transaction.

    This function scans the transaction logs for L2ToL1Tx events and converts them
    into withdrawal objects. For each event, it attempts to find a corresponding
    message record in the database to determine the message status. If a message
    record is not found (e.g., due to database inconsistency or fetcher issues),
    the function attempts to restore the message status through requests to the RPC
    node.

    ## Parameters
    - `transaction_hash`: The hash of the transaction to scan for L2ToL1Tx events

    ## Returns
    - A list of `Explorer.Arbitrum.Withdraw.t()` objects, each representing a single
      L2->L1 message initiated by the transaction. The list may be empty if no
      L2ToL1Tx events are found.
  """
  @spec transaction_to_withdrawals(Hash.Full.t()) :: [Explorer.Arbitrum.Withdraw.t()]
  def transaction_to_withdrawals(transaction_hash) do
    # request messages initiated by the provided transaction from the database
    messages = MessagesReader.l2_to_l1_messages_by_transaction_hash(transaction_hash)

    # request associated logs from the database
    logs = GeneralReader.transaction_to_logs_by_topic0(transaction_hash, ArbitrumEvents.l2_to_l1())

    logs
    |> Enum.map(fn log ->
      msg = Enum.find(messages, fn msg -> msg.message_id == Hash.to_integer(log.fourth_topic) end)

      # `msg` is needed to retrieve the message status
      # Regularly the message should be found, but in rare cases (database inconsistent, fetcher issues) it may omit.
      # In this case log_to_withdrawal/1 will be used to retrieve L2->L1 message status from the RPC node
      log_to_withdrawal(log, msg)
    end)
  end

  @doc """
    Constructs calldata for claiming an L2->L1 message on the L1 chain.

    This function retrieves the L2->L1 message record from the database by the given
    message ID and generates the proof and calldata needed for executing the message
    through the Outbox contract on L1. Only messages with :confirmed status can be
    claimed.

    ## Parameters
    - `message_id`: The unique identifier of the L2->L1 message (`position` field of
      the associated `L2ToL1Tx` event)

    ## Returns
    - `{:ok, [contract_address: String.t(), calldata: String.t()]}` where:
      * `contract_address` is the L1 Outbox contract address
      * `calldata` is the ABI-encoded executeTransaction function call
    - `{:error, :not_found}` if either:
      * the message with the given ID cannot be found in the database
      * the associated L2ToL1Tx event log cannot be found
    - `{:error, :initiated}` if the message is not yet confirmed
    - `{:error, :sent}` if the message is not yet confirmed
    - `{:error, :relayed}` if the message has already been claimed
    - `{:error, :internal_error}` if the message status is unknown
  """
  @spec claim(non_neg_integer()) :: {:ok, [contract_address: String.t(), calldata: String.t()]} | {:error, term()}
  def claim(message_id) do
    case MessagesReader.l2_to_l1_message_by_id(message_id) do
      nil ->
        Logger.error("Unable to find withdrawal with id #{message_id}")
        {:error, :not_found}

      message ->
        claim_message(message)
    end
  end

  # Constructs calldata for claiming an L2->L1 message on L1.
  #
  # This function retrieves the L2ToL1Tx event log associated with the message and
  # verifies the message status. Only messages with :confirmed status can be claimed.
  # For confirmed messages, it generates calldata with the proof needed for executing
  # the message through the Outbox contract on L1.
  #
  # ## Parameters
  # - `message`: The L2->L1 message record containing transaction details and status
  #
  # ## Returns
  # - `{:ok, [contract_address: binary(), calldata: binary()]}` where:
  #   * `contract_address` is the L1 Outbox contract address
  #   * `calldata` is the ABI-encoded executeTransaction function call
  # - `{:error, :not_found}` if either:
  #   * the associated L2ToL1Tx event log cannot be found
  #   * the withdrawal cannot be found in the transaction logs
  # - `{:error, :initiated}` if the message is not yet confirmed
  # - `{:error, :sent}` if the message is not yet confirmed
  # - `{:error, :relayed}` if the message has already been claimed
  # - `{:error, :internal_error}` if the message status is unknown
  @spec claim_message(Explorer.Chain.Arbitrum.Message.t()) ::
          {:ok, list({:contract_address, binary()} | {:calldata, binary()})}
          | {:error, :initiated | :sent | :relayed | :internal_error}
  defp claim_message(message) do
    # request associated log from the database
    case message.originating_transaction_hash
         |> GeneralReader.transaction_to_logs_by_topic0(ArbitrumEvents.l2_to_l1())
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

          w when w.status == :unknown ->
            {:error, :internal_error}
        end
    end
  end

  # Converts an L2ToL1Tx event log into a withdrawal structure using the provided message information.
  #
  # This function extracts withdrawal details from the L2ToL1Tx event log and combines
  # them with the message status from the database. For messages with status
  # :initiated or :sent, it verifies the actual message status since the database
  # status might be outdated if Arbitrum-specific fetchers were stopped. Also
  # extracts token transfer information if the message represents a token withdrawal.
  #
  # ## Parameters
  # - `log`: The L2ToL1Tx event log containing withdrawal information
  # - `message`: The message record from database containing status information, or
  #   `nil` to fall back to `log_to_withdrawal/1`
  #
  # ## Returns
  # - An Explorer.Arbitrum.Withdraw struct representing the withdrawal, or
  # - `nil` if the message ID from the log doesn't match the provided message
  @spec log_to_withdrawal(
          Explorer.Chain.Log.t(),
          Explorer.Chain.Arbitrum.Message.t() | nil
        ) :: Explorer.Arbitrum.Withdraw.t() | nil

  defp log_to_withdrawal(log, nil) do
    log_to_withdrawal(log)
  end

  # TODO: Consider adding a caching mechanism here to reduce the number of DB operations.
  # Keep in mind that caching Withdraw here may cause incorrect behavior due to
  # the variable fields (status, completion_transaction_hash).
  defp log_to_withdrawal(log, message) do
    # getting needed fields from the L2ToL1Tx event
    fields =
      log
      |> convert_explorer_log_to_map()
      |> ArbitrumRpc.l2_to_l1_event_parse()

    if fields.message_id == message.message_id do
      # extract token withdrawal info from the associated event's data
      token = obtain_token_withdrawal_data(fields.data)

      data_hex =
        fields.data
        |> Base.encode16(case: :lower)

      {:ok, caller_address} = Hash.Address.cast(fields.caller)
      {:ok, destination_address} = Hash.Address.cast(fields.destination)

      # For :initiated and :sent statuses, we need to verify the actual message status
      # since the database status could be outdated if Arbitrum fetchers were stopped.
      message_status =
        case message.status do
          status when status == :initiated or status == :sent ->
            get_actual_message_status(message.message_id)

          status ->
            status
        end

      %Explorer.Arbitrum.Withdraw{
        message_id: Hash.to_integer(log.fourth_topic),
        status: message_status,
        caller: caller_address,
        destination: destination_address,
        arb_block_number: fields.arb_block_number,
        eth_block_number: fields.eth_block_number,
        l2_timestamp: fields.timestamp,
        callvalue: fields.callvalue,
        data: "0x" <> data_hex,
        token: token,
        completion_transaction_hash: message.completion_transaction_hash
      }
    else
      Logger.error(
        "message_to_withdrawal: log doesn't correspond message (#{fields.position} != #{message.message_id})"
      )

      nil
    end
  end

  # Converts an L2ToL1Tx event log into a withdrawal structure when the message
  # information is not available in the database.
  #
  # This function parses the event log data, extracts both the basic withdrawal
  # information and any associated token transfer data if the message represents a
  # token withdrawal (by examining the finalizeInboundTransfer calldata). Since the
  # message is not found in the database, the function attempts to determine its
  # current status by comparing the message ID with the total count of messages sent
  # from L2.
  #
  # This function attempts to extract completion_transaction_hash from
  # `Explorer.Chain.Arbitrum.Reader.Indexer.Messages` because extracting it directly
  # from the contract is too complex. So keep in mind that there is a possibility of
  # a nil value in this field for relayed withdrawals.
  #
  # ## Parameters
  # - `log`: The L2ToL1Tx event log containing withdrawal information
  #
  # ## Returns
  # - An Explorer.Arbitrum.Withdraw struct representing the withdrawal
  @spec log_to_withdrawal(Explorer.Chain.Log.t()) :: Explorer.Arbitrum.Withdraw.t()
  defp log_to_withdrawal(log) do
    # getting needed fields from the L2ToL1Tx event
    fields =
      log
      |> convert_explorer_log_to_map()
      |> ArbitrumRpc.l2_to_l1_event_parse()

    status = get_actual_message_status(fields.message_id)

    token = obtain_token_withdrawal_data(fields.data)

    data_hex =
      fields.data
      |> Base.encode16(case: :lower)

    {:ok, caller_address} = Hash.Address.cast(fields.caller)
    {:ok, destination_address} = Hash.Address.cast(fields.destination)

    message_id = Hash.to_integer(log.fourth_topic)

    # try to find indexed L1 execution for the message
    execution_transaction_hash =
      case MessagesIndexerReader.l1_executions([message_id]) do
        [execution] -> execution.execution_transaction.hash
        _ -> nil
      end

    %Explorer.Arbitrum.Withdraw{
      message_id: message_id,
      status: status,
      caller: caller_address,
      destination: destination_address,
      arb_block_number: fields.arb_block_number,
      eth_block_number: fields.eth_block_number,
      l2_timestamp: fields.timestamp,
      callvalue: fields.callvalue,
      data: "0x" <> data_hex,
      token: token,
      completion_transaction_hash: execution_transaction_hash
    }
  end

  # Guesses the actual status of an L2->L1 message by analyzing data from the RPC node and the database
  #
  # The function first checks if the message has been spent (claimed) on L1 by
  # querying the Outbox contract. If the message is spent, its status is `:relayed`.
  # Otherwise, the function determines the message status by comparing its ID with
  # the total count of messages sent from rollup up to the most recent confirmed
  # rollup block. For L2->L1 message claiming purposes it is not needed to distinguish
  # between `:sent` and `:initiated` statuses since in either of this statuses means
  # that the message cannot be claimed yet.
  #
  # ## Parameters
  # - `message_id`: The unique identifier of the L2->L1 message
  #
  # ## Returns
  # - `:unknown` if unable to determine the message status
  # - `:sent` if the message is not yet confirmed
  # - `:confirmed` if the message is confirmed but not yet claimed
  # - `:relayed` if the message has been successfully claimed on L1
  @spec get_actual_message_status(non_neg_integer()) :: :unknown | :sent | :confirmed | :relayed
  defp get_actual_message_status(message_id) do
    # getting needed L1\L2 properties: RPC URL and Main Rollup contract address
    l1_rollup_address = get_l1_rollup_address()
    json_l1_rpc_named_arguments = get_json_rpc(:l1)

    outbox_contract =
      ArbitrumRpc.get_contracts_for_rollup(
        l1_rollup_address,
        :inbox_outbox,
        json_l1_rpc_named_arguments
      )[:outbox]

    {:ok, is_withdrawal_spent} =
      ArbitrumRpc.withdrawal_spent?(outbox_contract, message_id, json_l1_rpc_named_arguments)

    case is_withdrawal_spent do
      true ->
        :relayed

      false ->
        case get_size_for_proof() do
          nil -> :unknown
          size when size > message_id -> :confirmed
          _ -> :sent
        end
    end
  end

  # Converts an Explorer.Chain.Log struct into a map suitable for L2->L1 event parsing.
  #
  # This function transforms the log data into a format required by the
  # `EthereumJSONRPC.Arbitrum.l2_to_l1_event_parse/1` function.
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

  # Extracts token withdrawal information from the finalizeInboundTransfer calldata.
  #
  # The calldata is encapsulated in the L2ToL1Tx event and is meant to be executed on
  # the TokenBridge contract during withdrawal claiming.
  #
  # ## Parameters
  # - `data`: Binary data containing the finalizeInboundTransfer calldata
  #
  # ## Returns
  # - Map containing token contract `address`, `destination` address, token `amount`,
  #   token `name`, `symbol` and `decimals` if the data corresponds to finalizeInboundTransfer selector
  # - `nil` if data is void or doesn't match finalizeInboundTransfer method (which
  #   happens when the L2->L1 message is for arbitrary data transfer, such as a remote
  #   call of a smart contract on L1)
  @spec obtain_token_withdrawal_data(binary()) ::
          %{
            address_hash: Explorer.Chain.Hash.Address.t(),
            address: Explorer.Chain.Hash.Address.t(),
            destination: Explorer.Chain.Hash.Address.t(),
            amount: non_neg_integer(),
            decimals: non_neg_integer() | nil,
            name: binary() | nil,
            symbol: binary() | nil
          }
          | nil
  defp obtain_token_withdrawal_data(<<0x2E567B36::32, rest_data::binary>>) do
    [token, _, to, amount, _] = ABI.decode(ArbitrumContracts.finalize_inbound_transfer_selector_with_abi(), rest_data)

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

    # getting L1 RPC
    json_l1_rpc_named_arguments = get_json_rpc(:l1)

    # getting additional token properties needed to display purposes
    # TODO: it's need to cache token_info (e.g. with Explorer.Chain.OrderedCache) to reduce requests number
    token_info = ERC20.fetch_token_properties(ArbitrumRpc.value_to_address(token), json_l1_rpc_named_arguments)

    %{
      address_hash: token_bin,
      # todo: "address" should be removed in favour `address_hash` property with the next release after 8.0.0
      address: token_bin,
      destination_address_hash: to_bin,
      # todo: "destination" should be removed in favour `destination_address_hash` property with the next release after 8.0.0
      destination: to_bin,
      amount: amount,
      decimals: token_info.decimals,
      name: token_info.name,
      symbol: token_info.symbol
    }
  end

  defp obtain_token_withdrawal_data(_binary) do
    nil
  end

  # Builds a claim transaction calldata for executing an L2->L1 message on L1.
  #
  # Constructs calldata containing the proof needed to execute a withdrawal message
  # through the Outbox contract on L1. The function performs the following steps:
  # 1. Gets the total count of L2->L1 messages (size)
  # 2. Constructs the outbox proof using NodeInterface contract on the rollup
  # 3. Encodes the executeTransaction function call with the proof and message data
  #
  # ## Parameters
  # - `withdrawal`: A withdrawal message containing all necessary data for claim
  #   construction.
  #
  # ## Returns
  # - `{:ok, [contract_address: binary(), calldata: binary()]}` where:
  #   * `contract_address` is the L1 Outbox contract address
  #   * `calldata` is the ABI-encoded executeTransaction function call
  # - `{:error, :internal_error}` if proof construction fails
  @spec construct_claim(Explorer.Arbitrum.Withdraw.t()) ::
          {:ok, [contract_address: binary(), calldata: binary()]} | {:error, :internal_error}
  defp construct_claim(withdrawal) do
    # getting needed L1 properties: RPC URL and Main Rollup contract address
    json_l1_rpc_named_arguments = get_json_rpc(:l1)
    json_l2_rpc_named_arguments = get_json_rpc(:l2)
    l1_rollup_address = get_l1_rollup_address()

    outbox_contract =
      ArbitrumRpc.get_contracts_for_rollup(l1_rollup_address, :inbox_outbox, json_l1_rpc_named_arguments)[:outbox]

    case get_size_for_proof() do
      nil ->
        Logger.error("Cannot get size for proof")
        {:error, :internal_error}

      size ->
        # now we are ready to construct outbox proof
        case ArbitrumRpc.construct_outbox_proof(
               ArbitrumContracts.node_interface_contract_address(),
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

            calldata = Encoder.encode_function_call(ArbitrumContracts.execute_transaction_selector_with_abi(), args)

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
    |> Enum.map(fn p -> %Data{bytes: p} |> to_string() end)
  end

  # Retrieves the size parameter (total count of L2->L1 messages) needed for outbox
  # proof construction. First attempts to fetch from the local database, falling back
  # to RPC requests if necessary.
  @spec get_size_for_proof() :: non_neg_integer() | nil
  defp get_size_for_proof do
    case get_size_for_proof_from_database() do
      nil ->
        Logger.warning("The database doesn't contain required data to construct proof. Fallback to direct RPC request")

        l1_rollup_address = get_l1_rollup_address()
        json_l1_rpc_named_arguments = get_json_rpc(:l1)
        json_l2_rpc_named_arguments = get_json_rpc(:l2)

        get_size_for_proof_from_rpc(l1_rollup_address, json_l1_rpc_named_arguments, json_l2_rpc_named_arguments)

      size ->
        size
    end
  end

  # Retrieves the size parameter (total count of L2->L1 messages) needed for outbox
  # proof construction using data from the database.
  #
  # The function gets the highest confirmed block number and retrieves its
  # associated send_count value, which represents the cumulative count of L2->L1
  # messages.
  #
  # ## Returns
  # - Total count of L2->L1 messages up to the latest confirmed rollup block
  # - `nil` if the required data is not found in the database
  @spec get_size_for_proof_from_database() :: non_neg_integer() | nil
  defp get_size_for_proof_from_database do
    case SettlementReader.highest_confirmed_block() do
      nil ->
        nil

      highest_confirmed_block ->
        case Chain.number_to_block(highest_confirmed_block) do
          {:ok, block} -> Map.get(block, :send_count)
          _ -> nil
        end
    end
  end

  # Retrieves the size parameter (total count of L2->L1 messages) needed for outbox
  # proof construction via RPC calls.
  #
  # Note: The "size" parameter represents the cumulative count of L2->L1 messages
  # that have been sent up to the latest confirmed node.
  #
  # This function performs the following steps:
  # 1. Gets the latest confirmed node index from the L1 rollup contract
  # 2. Retrieves the L1 block number where that node was created
  # 3. Uses the block number to determine the total count of L2->L1 messages
  #
  # ## Parameters
  # - `l1_rollup_address`: Address of the Arbitrum rollup contract on L1
  # - `json_l1_rpc_named_arguments`: Configuration for L1 JSON-RPC connection
  # - `json_l2_rpc_named_arguments`: Configuration for rollup JSON-RPC connection
  #
  # ## Returns
  # - Total count of L2->L1 messages up to the latest confirmed node
  # - `nil` if any step in the process fails
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

  # Retrieves the total count of L2->L1 messages sent up to the rollup block associated
  # with a NodeCreated event in the specified L1 block.
  #
  # The function first fetches the NodeCreated event from the L1 block, extracts the
  # corresponding rollup block hash, and then retrieves the send_count value from that
  # rollup block. If the rollup block is not found in the database, falls back to
  # querying the rollup JSON-RPC endpoint directly.
  #
  # ## Parameters
  # - `node_creation_l1_block_number`: L1 block number containing a NodeCreated event
  # - `l1_rollup_address`: Address of the Rollup contract on L1
  # - `json_l1_rpc_named_arguments`: Configuration for L1 JSON-RPC connection
  # - `json_l2_rpc_named_arguments`: Configuration for rollup JSON-RPC connection
  #
  # ## Returns
  # - Number of L2->L1 messages sent up to the associated rollup block
  # - `nil` if the event cannot be found or block data cannot be retrieved
  @spec l1_block_number_to_withdrawals_count(
          non_neg_integer(),
          String.t(),
          EthereumJSONRPC.json_rpc_named_arguments(),
          EthereumJSONRPC.json_rpc_named_arguments()
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
           [ArbitrumEvents.node_created()],
           json_l1_rpc_named_arguments
         ) do
      {:ok, events} when is_list(events) and length(events) > 0 ->
        node_created_event = List.last(events)
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

  # Retrieves the total count of L2->L1 messages sent up to a specific rollup block.
  #
  # First attempts to fetch the block from the database. If not found, falls back
  # to querying the rollup JSON-RPC endpoint directly.
  #
  # ## Parameters
  # - `l2_block_hash`: The full hash of the rollup block to query
  # - `json_l2_rpc_named_arguments`: Configuration options for the rollup JSON-RPC
  #   connection
  #
  # ## Returns
  # - The `send_count` value from the block representing total L2->L1 messages sent
  # - `nil` if the block cannot be retrieved or an error occurs
  @spec messages_count_up_to_block_with_hash(Hash.Full.t(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          non_neg_integer() | nil
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

  # Extracts rollup block hash associated with the NodeCreated event emitted on L1
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
      |> TypeDecoder.decode_raw(ArbitrumEvents.node_created_unindexed_params())

    l2_block_hash
  end

  # Retrieve configuration options for the selected JSON-RPC connection (L1/L2)
  @spec get_json_rpc(:l1 | :l2) :: EthereumJSONRPC.json_rpc_named_arguments()
  defp get_json_rpc(:l1) do
    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    IndexerHelper.json_rpc_named_arguments(config_common[:l1_rpc])
  end

  defp get_json_rpc(:l2) do
    Application.get_env(:explorer, :json_rpc_named_arguments)
  end

  # Getting L1 Main Rollup contract address
  @spec get_l1_rollup_address() :: EthereumJSONRPC.address()
  defp get_l1_rollup_address do
    Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum][:l1_rollup_address]
  end
end
