defmodule Indexer.Fetcher.Arbitrum.Utils.Rpc do
  @moduledoc """
    Common functions to simplify RPC routines for Indexer.Fetcher.Arbitrum fetchers
  """

  import EthereumJSONRPC,
    only: [json_rpc: 2, quantity_to_integer: 1, timestamp_to_datetime: 1]

  alias EthereumJSONRPC.Transport
  alias Indexer.Helper, as: IndexerHelper

  @zero_hash "0000000000000000000000000000000000000000000000000000000000000000"
  @rpc_resend_attempts 20

  @default_binary_search_threshold 1000

  # outbox()
  @selector_outbox "ce11e6ab"
  # sequencerInbox()
  @selector_sequencer_inbox "ee35f327"
  # bridge()
  @selector_bridge "e78cea92"
  @rollup_contract_abi [
    %{
      "inputs" => [],
      "name" => "outbox",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "sequencerInbox",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "bridge",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  # getKeysetCreationBlock(bytes32 ksHash)
  @selector_get_keyset_creation_block "258f0495"
  @selector_sequencer_inbox_contract_abi [
    %{
      "inputs" => [%{"internalType" => "bytes32", "name" => "ksHash", "type" => "bytes32"}],
      "name" => "getKeysetCreationBlock",
      "outputs" => [%{"internalType" => "uint256", "name" => "", "type" => "uint256"}],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  # findBatchContainingBlock(uint64 blockNum)
  @selector_find_batch_containing_block "81f1adaf"
  @node_interface_contract_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "uint64",
          "name" => "blockNum",
          "type" => "uint64"
        }
      ],
      "name" => "findBatchContainingBlock",
      "outputs" => [
        %{
          "internalType" => "uint64",
          "name" => "batch",
          "type" => "uint64"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @doc """
    Constructs a JSON RPC request to retrieve a transaction by its hash.

    ## Parameters
    - `%{hash: tx_hash, id: id}`: A map containing the transaction hash (`tx_hash`) and
      an identifier (`id`) for the request, which can be used later to establish
      correspondence between requests and responses.

    ## Returns
    - A `Transport.request()` struct representing the JSON RPC request for fetching
      the transaction details associated with the given hash.
  """
  @spec transaction_by_hash_request(%{hash: EthereumJSONRPC.hash(), id: non_neg_integer()}) :: Transport.request()
  def transaction_by_hash_request(%{id: id, hash: tx_hash})
      when is_binary(tx_hash) and is_integer(id) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getTransactionByHash", params: [tx_hash]})
  end

  @doc """
    Retrieves specific contract addresses associated with Arbitrum rollup contract.

    This function fetches the addresses of the bridge, sequencer inbox, and outbox
    contracts related to the specified Arbitrum rollup address. It invokes one of
    the contract methods `bridge()`, `sequencerInbox()`, or `outbox()` based on
    the `contracts_set` parameter to obtain the required information.

    ## Parameters
    - `rollup_address`: The address of the Arbitrum rollup contract from which
                        information is being retrieved.
    - `contracts_set`: A symbol indicating the set of contracts to retrieve (`:bridge`
                       for the bridge contract, `:inbox_outbox` for the sequencer
                       inbox and outbox contracts).
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A map with keys corresponding to the contract types (`:bridge`, `:sequencer_inbox`,
      `:outbox`) and values representing the contract addresses.
  """
  @spec get_contracts_for_rollup(
          EthereumJSONRPC.address(),
          :bridge | :inbox_outbox,
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: %{(:bridge | :sequencer_inbox | :outbox) => binary()}
  def get_contracts_for_rollup(rollup_address, contracts_set, json_rpc_named_arguments)

  def get_contracts_for_rollup(rollup_address, :bridge, json_rpc_named_arguments) do
    call_simple_getters_in_rollup_contract(rollup_address, [@selector_bridge], json_rpc_named_arguments)
  end

  def get_contracts_for_rollup(rollup_address, :inbox_outbox, json_rpc_named_arguments) do
    call_simple_getters_in_rollup_contract(
      rollup_address,
      [@selector_sequencer_inbox, @selector_outbox],
      json_rpc_named_arguments
    )
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
      @selector_get_keyset_creation_block,
      [keyset_hash],
      @selector_sequencer_inbox_contract_abi,
      json_rpc_named_arguments
    )
  end

  # Calls getter functions on a rollup contract and collects their return values.
  #
  # This function is designed to interact with a rollup contract and invoke specified getter methods.
  # It creates a list of requests for each method ID, executes these requests with retries as needed,
  # and then maps the results to the corresponding method IDs.
  #
  # ## Parameters
  # - `rollup_address`: The address of the rollup contract to interact with.
  # - `method_ids`: A list of method identifiers representing the getter functions to be called.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - A map where each key is a method identifier converted to an atom, and each value is the
  #   response from calling the respective method on the contract.
  defp call_simple_getters_in_rollup_contract(rollup_address, method_ids, json_rpc_named_arguments) do
    method_ids
    |> Enum.map(fn method_id ->
      %{
        contract_address: rollup_address,
        method_id: method_id,
        args: []
      }
    end)
    |> IndexerHelper.read_contracts_with_retries(@rollup_contract_abi, json_rpc_named_arguments, @rpc_resend_attempts)
    # Extracts the list of responses from the tuple returned by read_contracts_with_retries.
    |> Kernel.elem(0)
    |> Enum.zip(method_ids)
    |> Enum.reduce(%{}, fn {{:ok, [response]}, method_id}, retval ->
      Map.put(retval, atomized_key(method_id), response)
    end)
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
    - `txs_requests`: A list of `Transport.request()` instances representing the transaction requests.
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
  def execute_transactions_requests_and_get_from(txs_requests, json_rpc_named_arguments, chunk_size)
      when is_list(txs_requests) and is_integer(chunk_size) do
    txs_requests
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

      next_block_to_inspect = max(1, inspected_block - new_step)

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
        @selector_find_batch_containing_block,
        [block_number],
        @node_interface_contract_abi,
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
        ) :: non_neg_integer()
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
    |> json_tx_id_to_hash()
    |> Base.decode16!(case: :mixed)
  end

  defp json_tx_id_to_hash(hash) do
    case hash do
      "0x" <> tx_hash -> tx_hash
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

  defp atomized_key(@selector_outbox), do: :outbox
  defp atomized_key(@selector_sequencer_inbox), do: :sequencer_inbox
  defp atomized_key(@selector_bridge), do: :bridge
end
