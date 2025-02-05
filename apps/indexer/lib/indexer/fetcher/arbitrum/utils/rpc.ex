defmodule Indexer.Fetcher.Arbitrum.Utils.Rpc do
  @moduledoc """
    Common functions to simplify RPC routines for Indexer.Fetcher.Arbitrum fetchers
  """

  # TODO: Move the module under EthereumJSONRPC.Arbitrum.

  alias ABI.TypeDecoder

  import EthereumJSONRPC,
    only: [json_rpc: 2, quantity_to_integer: 1, timestamp_to_datetime: 1]

  alias EthereumJSONRPC.Arbitrum.Constants.Contracts, as: ArbitrumContracts

  alias EthereumJSONRPC.Transport
  alias Indexer.Helper, as: IndexerHelper

  @zero_hash "0000000000000000000000000000000000000000000000000000000000000000"
  @rpc_resend_attempts 20

  @default_binary_search_threshold 1000

  @doc """
    Constructs a JSON RPC request to retrieve a transaction by its hash.

    ## Parameters
    - `%{hash: transaction_hash, id: id}`: A map containing the transaction hash (`transaction_hash`) and
      an identifier (`id`) for the request, which can be used later to establish
      correspondence between requests and responses.

    ## Returns
    - A `Transport.request()` struct representing the JSON RPC request for fetching
      the transaction details associated with the given hash.
  """
  @spec transaction_by_hash_request(%{hash: EthereumJSONRPC.hash(), id: non_neg_integer()}) :: Transport.request()
  def transaction_by_hash_request(%{id: id, hash: transaction_hash})
      when is_binary(transaction_hash) and is_integer(id) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getTransactionByHash", params: [transaction_hash]})
  end

  @doc """
    Retrieves the block number associated with a specific keyset from the Sequencer Inbox contract.

    This function performs an `eth_call` to the Sequencer Inbox contract to get the block number
    when a keyset was created.

    ## Parameters
    - `sequencer_inbox_address`: The address of the Sequencer Inbox contract.
    - `keyset_hash`: The hash of the keyset for which the block number is to be retrieved.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - The block number.
  """
  @spec get_block_number_for_keyset(
          EthereumJSONRPC.address(),
          EthereumJSONRPC.hash(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: non_neg_integer()
  def get_block_number_for_keyset(sequencer_inbox_address, keyset_hash, json_rpc_named_arguments) do
    read_contract_and_handle_result_as_integer(
      sequencer_inbox_address,
      ArbitrumContracts.get_keyset_creation_block_selector(),
      [keyset_hash],
      ArbitrumContracts.sequencer_inbox_contract_abi(),
      json_rpc_named_arguments
    )
  end

  @doc """
    Executes a batch of RPC calls and returns a list of response bodies.

    This function processes a list of RPC requests and returns only the response bodies,
    discarding the request IDs. The function is designed for scenarios where only
    the response data is required, and the association with request IDs is not needed.

    ## Parameters
    - `requests_list`: A list of `Transport.request()` instances representing the RPC calls to be made.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
    - `help_str`: A string that helps identify the request type in log messages, used for error logging.

    ## Returns
    - A list containing the bodies of the RPC call responses. This list will include both
      successful responses and errors encountered during the batch execution. The developer
      must handle these outcomes as appropriate.
  """
  @spec make_chunked_request([Transport.request()], EthereumJSONRPC.json_rpc_named_arguments(), binary()) :: list()
  def make_chunked_request(requests_list, json_rpc_named_arguments, help_str)

  def make_chunked_request([], _, _) do
    []
  end

  def make_chunked_request(requests_list, json_rpc_named_arguments, help_str)
      when is_list(requests_list) and is_binary(help_str) do
    requests_list
    |> make_chunked_request_keep_id(json_rpc_named_arguments, help_str)
    |> Enum.map(fn %{result: resp_body} -> resp_body end)
  end

  @doc """
    Executes a batch of RPC calls while preserving the original request IDs in the responses.

    This function processes a list of RPC requests in batches, retaining the association
    between the requests and their responses to ensure that each response can be traced
    back to its corresponding request.

    ## Parameters
    - `requests_list`: A list of `Transport.request()` instances representing the RPC calls to be made.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
    - `help_str`: A string that helps identify the request type in log messages, used for error logging.

    ## Returns
    - A list of maps, each containing the `id` and `result` from the RPC response, maintaining
      the same order and ID as the original request. If the batch execution encounters errors
      that cannot be resolved after the defined number of retries, the function will log
      the errors using the provided `help_str` for context and will return a list of responses
      where each element is either the result of a successful call or an error description.
      It is the responsibility of the developer to distinguish between successful responses
      and errors and handle them appropriately.
  """
  @spec make_chunked_request_keep_id([Transport.request()], EthereumJSONRPC.json_rpc_named_arguments(), binary()) ::
          [%{id: non_neg_integer(), result: any()}]
  def make_chunked_request_keep_id(requests_list, json_rpc_named_arguments, help_str)

  def make_chunked_request_keep_id([], _, _) do
    []
  end

  def make_chunked_request_keep_id(requests_list, json_rpc_named_arguments, help_str)
      when is_list(requests_list) and is_binary(help_str) do
    error_message_generator = &"Cannot call #{help_str}. Error: #{inspect(&1)}"

    {:ok, responses} =
      IndexerHelper.repeated_batch_rpc_call(
        requests_list,
        json_rpc_named_arguments,
        error_message_generator,
        @rpc_resend_attempts
      )

    responses
  end

  @doc """
    Executes a list of block requests, retrieves their timestamps, and returns a map of block numbers to timestamps.

    ## Parameters
    - `blocks_requests`: A list of `Transport.request()` instances representing the block
                         information requests.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
    - `chunk_size`: The number of requests to be processed in each batch, defining the size of the chunks.

    ## Returns
    - A map where each key is a block number and each value is the corresponding timestamp.
  """
  @spec execute_blocks_requests_and_get_ts(
          [Transport.request()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          non_neg_integer()
        ) :: %{EthereumJSONRPC.block_number() => DateTime.t()}
  def execute_blocks_requests_and_get_ts(blocks_requests, json_rpc_named_arguments, chunk_size)
      when is_list(blocks_requests) and is_integer(chunk_size) do
    blocks_requests
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce(%{}, fn chunk, result ->
      chunk
      |> make_chunked_request(json_rpc_named_arguments, "eth_getBlockByNumber")
      |> Enum.reduce(result, fn resp, result_inner ->
        Map.put(result_inner, quantity_to_integer(resp["number"]), timestamp_to_datetime(resp["timestamp"]))
      end)
    end)
  end

  @doc """
    Executes a list of transaction requests and retrieves the sender (from) addresses for each.

    ## Parameters
    - `transactions_requests`: A list of `Transport.request()` instances representing the transaction requests.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
    - `chunk_size`: The number of requests to be processed in each batch, defining the size of the chunks.

    ## Returns
    - A map where each key is a transaction hash and each value is the corresponding sender's address.
  """
  @spec execute_transactions_requests_and_get_from(
          [Transport.request()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          non_neg_integer()
        ) :: [%{EthereumJSONRPC.hash() => EthereumJSONRPC.address()}]
  def execute_transactions_requests_and_get_from(transactions_requests, json_rpc_named_arguments, chunk_size)
      when is_list(transactions_requests) and is_integer(chunk_size) do
    transactions_requests
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce(%{}, fn chunk, result ->
      chunk
      |> make_chunked_request(json_rpc_named_arguments, "eth_getTransactionByHash")
      |> Enum.reduce(result, fn resp, result_inner ->
        Map.put(result_inner, resp["hash"], resp["from"])
      end)
    end)
  end

  @doc """
    Retrieves the block number associated with a given block hash using the Ethereum JSON RPC `eth_getBlockByHash` method, with retry logic for handling request failures.

    ## Parameters
    - `hash`: The hash of the block for which the block number is requested.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - The block number if the block is found and successfully retrieved, or `nil`
      if the block cannot be fetched or the block number is not present in the response.
  """
  @spec get_block_number_by_hash(EthereumJSONRPC.hash(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          EthereumJSONRPC.block_number() | nil
  def get_block_number_by_hash(hash, json_rpc_named_arguments) do
    func = &do_get_block_number_by_hash/2
    args = [hash, json_rpc_named_arguments]
    error_message = &"Cannot fetch block #{hash} or its number. Error: #{inspect(&1)}"

    case IndexerHelper.repeated_call(func, args, error_message, @rpc_resend_attempts) do
      {:error, _} -> nil
      {:ok, res} -> res
    end
  end

  defp do_get_block_number_by_hash(hash, json_rpc_named_arguments) do
    # credo:disable-for-lines:3 Credo.Check.Refactor.PipeChainStart
    result =
      EthereumJSONRPC.request(%{id: 0, method: "eth_getBlockByHash", params: [hash, false]})
      |> json_rpc(json_rpc_named_arguments)

    with {:ok, block} <- result,
         false <- is_nil(block),
         number <- Map.get(block, "number"),
         false <- is_nil(number) do
      {:ok, quantity_to_integer(number)}
    else
      {:error, message} ->
        {:error, message}

      true ->
        {:error, "RPC returned nil."}
    end
  end

  @doc """
    Determines the starting block number for further operations with L1 based on configuration and network status.

    This function selects the starting block number for operations involving L1.
    If the configured block number is `0`, it attempts to retrieve the safe block number
    from the network. Should the safe block number not be available (if the endpoint does
    not support this feature), the latest block number is used instead. If a non-zero block
    number is configured, that number is used directly.

    ## Parameters
    - `configured_number`: The block number configured for starting operations.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - The block number from which to start further operations with L1, determined based
      on the provided configuration and network capabilities.
  """
  @spec get_l1_start_block(EthereumJSONRPC.block_number(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          EthereumJSONRPC.block_number()
  def get_l1_start_block(configured_number, json_rpc_named_arguments) do
    if configured_number == 0 do
      {block_number, _} = IndexerHelper.get_safe_block(json_rpc_named_arguments)
      block_number
    else
      configured_number
    end
  end

  @doc """
    Retrieves the safe and latest L1 block numbers.

    This function fetches the latest block number from the chain and tries to determine
    the safe block number. If the RPC node does not support the safe block feature or
    if the safe block is too far behind the latest block, the safe block is determined
    based on the finalization threshold. In both cases, it steps back from the latest
    block to mark some blocks as unfinalized.

    ## Parameters
    - `json_rpc_named_arguments`: The named arguments for the JSON RPC call.
    - `hard_limit`: The maximum number of blocks to step back when determining the safe block.

    ## Returns
    - A tuple containing the safe block number and the latest block number.
  """
  @spec get_safe_and_latest_l1_blocks(EthereumJSONRPC.json_rpc_named_arguments(), non_neg_integer()) ::
          {EthereumJSONRPC.block_number(), EthereumJSONRPC.block_number()}
  def get_safe_and_latest_l1_blocks(json_rpc_named_arguments, hard_limit) do
    finalization_threshold = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum][:l1_finalization_threshold]

    {safe_chain_block, is_latest?} = IndexerHelper.get_safe_block(json_rpc_named_arguments)

    latest_chain_block =
      case is_latest? do
        true ->
          safe_chain_block

        false ->
          {:ok, latest_block} =
            IndexerHelper.get_block_number_by_tag("latest", json_rpc_named_arguments, get_resend_attempts())

          latest_block
      end

    safe_block =
      if safe_chain_block < latest_chain_block + 1 - finalization_threshold or is_latest? do
        # The first condition handles the case when the safe block is too far behind
        # the latest block (L3 case).
        # The second condition handles the case when the L1 RPC node does not support
        # the safe block feature (non standard Arbitrum deployments).
        # In both cases, it is necessary to step back a bit from the latest block to
        # suspect these blocks as unfinalized.
        latest_chain_block + 1 - min(finalization_threshold, hard_limit)
      else
        safe_chain_block
      end

    {safe_block, latest_chain_block}
  end

  @doc """
    Identifies the block range for a batch by using the block number located on one end of the range.

    The function verifies suspicious block numbers by using the
    `findBatchContainingBlock` method of the Node Interface contract in a binary
    search.

    The sign of the step determines the direction of the search:
    - A positive step indicates the search is for the lowest block in the range.
    - A negative step indicates the search is for the highest block in the range.

    ## Parameters
    - `initial_block`: The starting block number for the search.
    - `initial_step`: The initial step size for the binary search.
    - `required_batch_number`: The target batch for which the blocks range is
      discovered.
    - `rollup_config`: A map containing the `NodeInterface` contract address and
      configuration parameters for the JSON RPC connection.

    ## Returns
    - A tuple `{start_block, end_block}` representing the range of blocks included
      in the specified batch.
  """
  @spec get_block_range_for_batch(
          EthereumJSONRPC.block_number(),
          integer(),
          non_neg_integer(),
          %{
            node_interface_address: EthereumJSONRPC.address(),
            json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments()
          }
        ) :: {non_neg_integer(), non_neg_integer()}
  def get_block_range_for_batch(
        initial_block,
        initial_step,
        required_batch_number,
        rollup_config
      ) do
    opposite_block =
      do_binary_search_of_opposite_block(
        max(1, initial_block - initial_step),
        initial_step,
        required_batch_number,
        rollup_config,
        required_batch_number,
        initial_block,
        %{}
      )

    # the default direction for the block range exploration is chosen to be from the highest to lowest
    # and the initial step is positive in this case
    if initial_step > 0 do
      {opposite_block, initial_block}
    else
      {initial_block, opposite_block}
    end
  end

  # Performs a binary search to find the opposite block for a rollup blocks
  # range included in a batch with the specified number. The function calls
  # `findBatchContainingBlock` of the Node Interface contract to determine the
  # batch number of the inspected block and, based on the call result and the
  # previously inspected block, decides whether the opposite block is found or
  # another iteration is required. In order to avoid redundant RPC calls, the
  # function uses a cache to store the batch numbers.
  #
  # Assumptions:
  # - The initial step is low enough to not jump more than one batch in a single
  #   iteration.
  # - The function can discover the opposite block in any direction depending on
  #   the sign of the step. If the step is positive, the lookup happens for the
  #   lowest block in the range. If the step is negative, the lookup is for the
  #   highest block in the range.
  #
  # Parameters:
  # - `inspected_block`: The block number currently being inspected.
  # - `step`: The step size used for the binary search.
  # - `required_batch_number`: The target batch for which blocks range is
  #   discovered.
  # - `rollup_config`: A map containing the `NodeInterface` contract address and
  #    configuration parameters for the JSON RPC connection.
  # - `prev_batch_number`: The number of the batch where the block was inspected
  #   on the previous iteration.
  # - `prev_inspected_block`: The block number that was previously inspected.
  # - `cache`: A map that stores the batch numbers for rollup blocks to avoid
  #   redundant RPC calls.
  # - `iteration_threshold`: The maximum number of iterations allowed for the
  #   binary search to avoid infinite loops.
  #
  # Returns:
  # - The block number of the opposite block in the rollup or raises an error if
  #   the iteration threshold is exceeded.
  @spec do_binary_search_of_opposite_block(
          non_neg_integer(),
          integer(),
          non_neg_integer(),
          %{
            node_interface_address: EthereumJSONRPC.address(),
            json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments()
          },
          non_neg_integer(),
          non_neg_integer(),
          %{non_neg_integer() => non_neg_integer()}
        ) :: non_neg_integer()
  @spec do_binary_search_of_opposite_block(
          non_neg_integer(),
          integer(),
          non_neg_integer(),
          %{
            node_interface_address: EthereumJSONRPC.address(),
            json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments()
          },
          non_neg_integer(),
          non_neg_integer(),
          %{non_neg_integer() => non_neg_integer()},
          non_neg_integer()
        ) :: non_neg_integer()
  defp do_binary_search_of_opposite_block(
         inspected_block,
         step,
         required_batch_number,
         %{node_interface_address: _, json_rpc_named_arguments: _} = rollup_config,
         prev_batch_number,
         prev_inspected_block,
         cache,
         iteration_threshold \\ @default_binary_search_threshold
       ) do
    if iteration_threshold == 0 do
      raise "Binary search iteration threshold exceeded"
    end

    {new_batch_number, new_cache} =
      get_batch_number_for_rollup_block(
        rollup_config.node_interface_address,
        inspected_block,
        rollup_config.json_rpc_named_arguments,
        cache
      )

    is_batch_repeated? = new_batch_number == prev_batch_number

    is_min_step_required_batch? =
      abs(prev_inspected_block - inspected_block) == 1 and new_batch_number == required_batch_number

    new_step =
      cond do
        # The batch number is the same as the previous one, so there is no need to reduce step and
        # the next iteration should continue in the same direction.
        is_batch_repeated? ->
          step

        # For the next two cases the batch number differs from one found in the previous iteration,
        # so it is necessary to cut the step in half and change the direction of the search if the
        # the next iteration assumed to move away from the required batch number.
        step > 0 ->
          adjust_step(step, new_batch_number <= required_batch_number)

        step < 0 ->
          adjust_step(step, new_batch_number >= required_batch_number)
      end

    if is_min_step_required_batch? and not is_batch_repeated? do
      # The current step is the smallest possible, the inspected block in the required batch but
      # the batch number is different from one found in the previous iteration. This means that
      # the previous block was in the neighboring batch and the current block is in the boundary
      # of the required batch.

      inspected_block
    else
      # Whether the required batch number is not reached yet, or there is uncertainty if the
      # inspected block is in the boundary of the required batch: the current batch is the same
      # as one found in the previous iteration or the step is not the smallest possible.

      # it is OK to use the earliest block 0 as since the corresponding batch (0)
      # will be returned by get_batch_number_for_rollup_block.
      next_block_to_inspect = max(0, inspected_block - new_step)

      do_binary_search_of_opposite_block(
        next_block_to_inspect,
        new_step,
        required_batch_number,
        rollup_config,
        new_batch_number,
        inspected_block,
        new_cache,
        iteration_threshold - 1
      )
    end
  end

  # Adjusts the step size for the binary search based on the current step size and
  # the need to change the direction of the search.
  @spec adjust_step(integer(), boolean()) :: integer()
  defp adjust_step(step, change_direction?) do
    case {abs(step), change_direction?} do
      {1, true} -> -step
      {1, false} -> step
      {_, true} -> -div(step, 2)
      {_, false} -> div(step, 2)
    end
  end

  # Retrieves the batch number for a given rollup block by interacting with the
  # Node Interface contract.
  #
  # This function calls the `findBatchContainingBlock` method of the Node Interface
  # contract to find the batch containing the specified block number. In order to
  # avoid redundant RPC calls, the function uses a cache to store the batch numbers.
  #
  # Parameters:
  # - `node_interface_address`: The address of the node interface contract.
  # - `block_number`: The rollup block number.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC
  #   connection.
  # - `cache`: A map that stores the batch numbers for rollup blocks to avoid
  #   redundant RPC calls.
  #
  # Returns:
  # `{batch_number, new_cache}`, where
  # - `batch_number` - The number of a batch containing the specified rollup block.
  # - `new_cache` - The updated cache with the new batch number.
  @spec get_batch_number_for_rollup_block(
          EthereumJSONRPC.address(),
          EthereumJSONRPC.block_number(),
          EthereumJSONRPC.json_rpc_named_arguments(),
          %{non_neg_integer() => non_neg_integer()}
        ) :: {non_neg_integer(), %{non_neg_integer() => non_neg_integer()}}
  defp get_batch_number_for_rollup_block(node_interface_address, block_number, json_rpc_named_arguments, cache)

  defp get_batch_number_for_rollup_block(_, block_number, _, cache) when is_map_key(cache, block_number) do
    {Map.get(cache, block_number), cache}
  end

  defp get_batch_number_for_rollup_block(node_interface_address, block_number, json_rpc_named_arguments, cache) do
    batch_number =
      read_contract_and_handle_result_as_integer(
        node_interface_address,
        ArbitrumContracts.find_batch_containing_block_selector(),
        [block_number],
        ArbitrumContracts.node_interface_contract_abi(),
        json_rpc_named_arguments
      )

    {batch_number, Map.put(cache, block_number, batch_number)}
  end

  # Calls one contract method and processes the result as an integer.
  @spec read_contract_and_handle_result_as_integer(
          EthereumJSONRPC.address(),
          binary(),
          [term()],
          [map()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: non_neg_integer() | boolean()
  defp read_contract_and_handle_result_as_integer(
         contract_address,
         method_selector,
         args,
         abi,
         json_rpc_named_arguments
       ) do
    [
      %{
        contract_address: contract_address,
        method_id: method_selector,
        args: args
      }
    ]
    |> IndexerHelper.read_contracts_with_retries(abi, json_rpc_named_arguments, @rpc_resend_attempts)
    # Extracts the list of responses from the tuple returned by read_contracts_with_retries.
    |> Kernel.elem(0)
    # Retrieves the first response from the list of responses. The responses are in a list
    # because read_contracts_with_retries accepts a list of method calls.
    |> List.first()
    # Extracts the result from the {status, result} tuple which is composed in EthereumJSONRPC.Encoder.decode_result.
    |> Kernel.elem(1)
    # Extracts the first decoded value from the result, which is a list, even if it contains only one value.
    |> List.first()
  end

  @doc """
    Converts a transaction hash from its hexadecimal string representation to a binary format.

    ## Parameters
    - `hash`: The transaction hash as a hex string, which can be `nil`. If `nil`, a default zero hash value is used.

    ## Returns
    - The binary representation of the hash. If the input is `nil`, returns the binary form of the default zero hash.
  """
  @spec string_hash_to_bytes_hash(EthereumJSONRPC.hash() | nil) :: binary()
  def string_hash_to_bytes_hash(hash) do
    hash
    |> json_transaction_id_to_hash()
    |> Base.decode16!(case: :mixed)
  end

  defp json_transaction_id_to_hash(hash) do
    case hash do
      "0x" <> transaction_hash -> transaction_hash
      nil -> @zero_hash
    end
  end

  @doc """
    Retrieves the hardcoded number of resend attempts for RPC calls.

    ## Returns
    - The number of resend attempts.
  """
  @spec get_resend_attempts() :: non_neg_integer()
  def get_resend_attempts do
    @rpc_resend_attempts
  end

  @doc """
    Parses the calldata of various Arbitrum Sequencer batch submission functions to extract batch information.

    Handles calldata for the following functions:
    - addSequencerL2BatchFromOrigin
    - addSequencerL2BatchFromBlobs
    - addSequencerL2BatchFromBlobsDelayProof
    - addSequencerL2BatchFromOriginDelayProof
    - addSequencerL2BatchDelayProof

    ## Parameters
    - `calldata`: The raw calldata from the transaction as a binary string starting with "0x"
                 followed by the function selector and encoded parameters

    ## Returns
    A tuple containing:
    - `sequence_number`: The batch sequence number
    - `prev_message_count`: The previous L2-to-L1 message count (nil for some functions)
    - `new_message_count`: The new L2-to-L1 message count (nil for some functions)
    - `data`: The batch data as binary (nil for blob-based submissions)
  """
  @spec parse_calldata_of_add_sequencer_l2_batch(binary()) ::
          {non_neg_integer(), non_neg_integer() | nil, non_neg_integer() | nil, binary() | nil}
  def parse_calldata_of_add_sequencer_l2_batch(calldata) do
    case calldata do
      "0x8f111f3c" <> encoded_params ->
        # addSequencerL2BatchFromOrigin(uint256 sequenceNumber, bytes calldata data, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount)
        [sequence_number, data, _after_delayed_messages_read, _gas_refunder, prev_message_count, new_message_count] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            ArbitrumContracts.add_sequencer_l2_batch_from_origin_8f111f3c_selector_with_abi()
          )

        {sequence_number, prev_message_count, new_message_count, data}

      "0x37501551" <> encoded_params ->
        # addSequencerL2BatchFromOrigin(uint256 sequenceNumber, bytes calldata data, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount, bytes quote)
        # https://github.com/EspressoSystems/nitro-contracts/blob/a61b9dbd71ca443f8e7a007851071f5f1d219c19/src/bridge/SequencerInbox.sol#L364-L372
        [
          sequence_number,
          data,
          _after_delayed_messages_read,
          _gas_refunder,
          prev_message_count,
          new_message_count,
          _quote
        ] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            ArbitrumContracts.add_sequencer_l2_batch_from_origin_37501551_selector_with_abi()
          )

        {sequence_number, prev_message_count, new_message_count, data}

      "0x3e5aa082" <> encoded_params ->
        # addSequencerL2BatchFromBlobs(uint256 sequenceNumber, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount)
        [sequence_number, _after_delayed_messages_read, _gas_refunder, prev_message_count, new_message_count] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            ArbitrumContracts.add_sequencer_l2_batch_from_blobs_selector_with_abi()
          )

        {sequence_number, prev_message_count, new_message_count, nil}

      "0x6f12b0c9" <> encoded_params ->
        # addSequencerL2BatchFromOrigin(uint256 sequenceNumber, bytes calldata data, uint256 afterDelayedMessagesRead, address gasRefunder)
        [sequence_number, data, _after_delayed_messages_read, _gas_refunder] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            ArbitrumContracts.add_sequencer_l2_batch_from_origin_6f12b0c9_selector_with_abi()
          )

        {sequence_number, nil, nil, data}

      "0x917cf8ac" <> encoded_params ->
        # addSequencerL2BatchFromBlobsDelayProof(uint256 sequenceNumber, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount, DelayProof calldata delayProof)
        [
          sequence_number,
          _after_delayed_messages_read,
          _gas_refunder,
          prev_message_count,
          new_message_count,
          _delay_proof
        ] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            ArbitrumContracts.add_sequencer_l2_batch_from_blobs_delay_proof_selector_with_abi()
          )

        {sequence_number, prev_message_count, new_message_count, nil}

      "0x69cacded" <> encoded_params ->
        # addSequencerL2BatchFromOriginDelayProof(uint256 sequenceNumber, bytes calldata data, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount, DelayProof calldata delayProof)
        [
          sequence_number,
          data,
          _after_delayed_messages_read,
          _gas_refunder,
          prev_message_count,
          new_message_count,
          _delay_proof
        ] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            ArbitrumContracts.add_sequencer_l2_batch_from_origin_delay_proof_selector_with_abi()
          )

        {sequence_number, prev_message_count, new_message_count, data}

      "0x6e620055" <> encoded_params ->
        # addSequencerL2BatchDelayProof(uint256 sequenceNumber, bytes calldata data, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount, DelayProof calldata delayProof)
        [
          sequence_number,
          data,
          _after_delayed_messages_read,
          _gas_refunder,
          prev_message_count,
          new_message_count,
          _delay_proof
        ] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            ArbitrumContracts.add_sequencer_l2_batch_delay_proof_selector_with_abi()
          )

        {sequence_number, prev_message_count, new_message_count, data}
    end
  end

  @doc """
    Extracts batch numbers from `SequencerBatchDelivered` event logs.

    Note: This function assumes that all provided logs are SequencerBatchDelivered
    events. Logs from other events should be filtered out before calling this
    function.

    ## Parameters
    - `logs`: A list of event logs, where each log is a map containing event data
             from the `SequencerBatchDelivered` event.

    ## Returns
    - A list of non-negative integers representing batch numbers.
  """
  @spec extract_batch_numbers_from_logs([%{String.t() => any()}]) :: [non_neg_integer()]
  def extract_batch_numbers_from_logs(logs) do
    logs
    |> Enum.map(fn event ->
      {batch_num, _, _} = parse_sequencer_batch_delivered_event(event)
      batch_num
    end)
  end

  # Parses SequencerBatchDelivered event to get batch sequence number and associated accumulators
  @doc """
    Extracts key information from a `SequencerBatchDelivered` event log.

    The event topics array contains the indexed parameters of the event:
    - topic[0]: Event signature (not used)
    - topic[1]: Batch number (indexed parameter)
    - topic[2]: Before accumulator value (indexed parameter)
    - topic[3]: After accumulator value (indexed parameter)

    Note: This function does not verify if the event is actually a
    `SequencerBatchDelivered` event.

    ## Parameters
    - `event`: A map containing event data with `topics` field.

    ## Returns
    - A tuple containing:
      - The batch number as an integer
      - The before accumulator value as a binary
      - The after accumulator value as a binary
  """
  @spec parse_sequencer_batch_delivered_event(%{String.t() => any()}) :: {non_neg_integer(), binary(), binary()}
  def parse_sequencer_batch_delivered_event(event) do
    [_, batch_sequence_number, before_acc, after_acc] = event["topics"]

    {quantity_to_integer(batch_sequence_number), before_acc, after_acc}
  end
end
