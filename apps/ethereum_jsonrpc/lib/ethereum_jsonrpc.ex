defmodule EthereumJSONRPC do
  @moduledoc """
  Ethereum JSONRPC client.

  ## Configuration

  Configuration for Nethermind URLs can be provided with the following mix config:

      config :ethereum_jsonrpc,
        url: "http://localhost:8545",
        trace_url: "http://localhost:8545",
        http: [recv_timeout: 60_000, timeout: 60_000, pool: :ethereum_jsonrpc]


  Note: the tracing node URL is provided separately from `:url`, via `:trace_url`. The trace URL and is used for
  `fetch_internal_transactions`, which is only a supported method on tracing nodes. The `:http` option is adapted
  to the HTTP library (`HTTPoison` or `Tesla.Mint`).

  ## Throttling

  Requests for fetching blockchain can put a lot of CPU pressure on JSON RPC
  nodes. EthereumJSONRPC will check for request timeouts as well as bad-gateway
  responses and add delay between requests until the JSON RPC nodes reach
  stability. For finer tuning and configuration of throttling, read the
  documentation for `EthereumJSONRPC.RequestCoordinator`.
  """

  require Logger

  alias EthereumJSONRPC.{
    Block,
    Blocks,
    Contract,
    FetchedBalances,
    FetchedBeneficiaries,
    FetchedCodes,
    Nonces,
    Receipts,
    RequestCoordinator,
    Subscription,
    Transport,
    Utility.CommonHelper,
    Utility.EndpointAvailabilityObserver,
    Utility.RangesHelper,
    Variant
  }

  @default_throttle_timeout :timer.minutes(2)

  @typedoc """
  Truncated 20-byte [KECCAK-256](https://en.wikipedia.org/wiki/SHA-3) hash encoded as a hexadecimal number in a
  `String.t`.
  """
  @type address :: String.t()

  @typedoc """
  A block number as an Elixir `t:non_neg_integer/0` instead of `t:data/0`.
  """
  @type block_number :: non_neg_integer()

  @typedoc """
  Reference to an uncle block by nephew block's `hash` and `index` in it.
  """
  @type nephew_index :: %{required(:nephew_hash) => String.t(), required(:index) => non_neg_integer()}

  @typedoc """
  Binary data encoded as a single hexadecimal number in a `String.t`
  """
  @type data :: String.t()

  @typedoc """
  Contract code encoded as a single hexadecimal number in a `String.t`
  """
  @type code :: String.t()

  @typedoc """
  A full 32-byte [KECCAK-256](https://en.wikipedia.org/wiki/SHA-3) hash encoded as a hexadecimal number in a `String.t`

  ## Example

     "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331"

  """
  @type hash :: String.t()

  @typedoc """
  Named arguments to `json_rpc/2`.

   * `:transport` - the `t:EthereumJSONRPC.Transport.t/0` callback module
   * `:transport_options` - options passed to `c:EthereumJSONRPC.Transport.json_rpc/2`
   * `:variant` - the `t:EthereumJSONRPC.Variant.t/0` callback module
   * `:throttle_timeout` - the maximum amount of time in milliseconds to throttle
     before automatically returning a timeout. Defaults to #{@default_throttle_timeout} milliseconds.
  """
  @type json_rpc_named_arguments :: [
          {:transport, Transport.t()}
          | {:transport_options, Transport.options()}
          | {:variant, Variant.t()}
          | {:throttle_timeout, non_neg_integer()}
        ]

  @typedoc """
  Named arguments to `subscribe/2`.

  * `:transport` - the `t:EthereumJSONRPC.Transport.t/0` callback module
  * `:transport_options` - options passed to `c:EthereumJSONRPC.Transport.json_rpc/2`
  * `:variant` - the `t:EthereumJSONRPC.Variant.t/0` callback module
  """
  @type subscribe_named_arguments :: [
          {:transport, Transport.t()} | {:transport_options, Transport.options()} | {:variant, Variant.t()}
        ]

  @typedoc """
  8 byte [KECCAK-256](https://en.wikipedia.org/wiki/SHA-3) hash of the proof-of-work.
  """
  @type nonce :: String.t()

  @typedoc """
  A number encoded as a hexadecimal number in a `String.t`

  ## Example

      "0x1b4"

  """
  @type quantity :: String.t()

  @typedoc """
  A logic block tag that can be used in place of a block number.

  | Tag          | Description                    |
  |--------------|--------------------------------|
  | `"earliest"` | The first block in the chain   |
  | `"latest"`   | The latest collated block.     |
  | `"pending"`  | The next block to be collated. |
  """
  @type tag :: String.t()

  @typedoc """
  Unix timestamp encoded as a hexadecimal number in a `String.t`
  """
  @type timestamp :: String.t()

  @typedoc """
  JSONRPC request id can be a `String.t` or Integer
  """
  @type request_id :: String.t() | non_neg_integer()

  @doc """
  Execute smart contract functions.

  Receives a list of smart contract functions to execute. Each function is
  represented by a map. The contract_address key is the address of the smart
  contract being queried, the data key indicates which function should be
  executed, as well as what are their arguments, and the id key is the id that
  is going to be sent with the JSON-RPC call.

  ## Examples

  Execute the "sum" function that receives two arguments (20 and 22) and returns their sum (42):
  iex> EthereumJSONRPC.execute_contract_functions([%{
  ...> contract_address: "0x7e50612682b8ee2a8bb94774d50d6c2955726526",
  ...> data: "0xcad0899b00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000016",
  ...> id: "sum"
  ...> }])
  {:ok,
    [
      %{
        "id" => "sum",
        "jsonrpc" => "2.0",
        "result" => "0x000000000000000000000000000000000000000000000000000000000000002a"
      }
    ]}
  """
  @spec execute_contract_functions([Contract.call()], [map()], json_rpc_named_arguments) :: [Contract.call_result()]
  def execute_contract_functions(functions, abi, json_rpc_named_arguments, leave_error_as_map \\ false) do
    if Enum.empty?(functions) do
      []
    else
      Contract.execute_contract_functions(functions, abi, json_rpc_named_arguments, leave_error_as_map)
    end
  end

  @doc """
  Fetches balance for each address `hash` at the `block_number`
  """
  @spec fetch_balances(
          [%{required(:block_quantity) => quantity, required(:hash_data) => data()}],
          json_rpc_named_arguments
        ) :: {:ok, FetchedBalances.t()} | {:error, reason :: term}
  def fetch_balances(params_list, json_rpc_named_arguments, latest_block_number \\ 0, chunk_size \\ nil)
      when is_list(params_list) and is_list(json_rpc_named_arguments) do
    latest_block_number_params =
      case latest_block_number do
        0 -> fetch_block_number_by_tag("latest", json_rpc_named_arguments)
        number -> {:ok, number}
      end

    params_in_range =
      params_list
      |> Enum.filter(fn
        %{block_quantity: block_quantity} ->
          block_quantity |> quantity_to_integer() |> RangesHelper.traceable_block_number?()
      end)

    trace_url_used? = !is_nil(json_rpc_named_arguments[:transport_options][:method_to_url][:eth_getBalance])
    archive_disabled? = Application.get_env(:ethereum_jsonrpc, :disable_archive_balances?)

    {latest_balances_params, archive_balance_params} =
      with true <- not trace_url_used? or archive_disabled?,
           {:ok, max_block_number} <- latest_block_number_params do
        window = Application.get_env(:ethereum_jsonrpc, :archive_balances_window)

        Enum.split_with(params_in_range, fn
          %{block_quantity: "latest"} -> true
          %{block_quantity: block_quantity} -> quantity_to_integer(block_quantity) > max_block_number - window
          _ -> false
        end)
      else
        _ -> {params_in_range, []}
      end

    latest_id_to_params = id_to_params(latest_balances_params)
    archive_id_to_params = id_to_params(archive_balance_params)

    with {:ok, latest_responses} <- do_balances_request(latest_id_to_params, chunk_size, json_rpc_named_arguments),
         {:ok, archive_responses} <-
           maybe_request_archive_balances(
             archive_id_to_params,
             trace_url_used?,
             archive_disabled?,
             chunk_size,
             json_rpc_named_arguments
           ) do
      latest_fetched_balances = FetchedBalances.from_responses(latest_responses, latest_id_to_params)
      archive_fetched_balances = FetchedBalances.from_responses(archive_responses, archive_id_to_params)
      {:ok, FetchedBalances.merge(latest_fetched_balances, archive_fetched_balances)}
    end
  end

  @doc """
  Fetches transactions count for every `block_number`
  """
  @spec fetch_transactions_count([integer()], json_rpc_named_arguments) ::
          {:ok, %{transactions_count_map: %{integer() => integer()}, errors: [{:error, map()}]}}
          | {:error, reason :: term()}
  def fetch_transactions_count(block_numbers, json_rpc_named_arguments) do
    id_to_params = EthereumJSONRPC.id_to_params(block_numbers)

    id_to_params
    |> Enum.map(fn {id, number} ->
      EthereumJSONRPC.request(%{
        id: id,
        method: "eth_getBlockTransactionCountByNumber",
        params: [EthereumJSONRPC.integer_to_quantity(number)]
      })
    end)
    |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)
    |> case do
      {:ok, responses} ->
        %{errors: errors, counts: counts} =
          responses
          |> EthereumJSONRPC.sanitize_responses(id_to_params)
          |> Enum.reduce(%{errors: [], counts: %{}}, fn
            %{id: id, result: nil}, %{errors: errors} = acc ->
              error = {:error, %{code: 404, message: "Not Found", data: Map.fetch!(id_to_params, id)}}
              %{acc | errors: [error | errors]}

            %{id: id, result: count}, %{counts: counts} = acc ->
              %{acc | counts: Map.put(counts, Map.fetch!(id_to_params, id), EthereumJSONRPC.quantity_to_integer(count))}

            %{id: id, error: error}, %{errors: errors} = acc ->
              %{acc | errors: [{:error, Map.put(error, :data, Map.fetch!(id_to_params, id))} | errors]}
          end)

        {:ok, %{transactions_count_map: Map.new(counts), errors: errors}}

      error ->
        error
    end
  end

  @doc """
    Fetches contract code for multiple addresses at specified block numbers.

    This function takes a list of parameters, each containing an address and a
    block number, and retrieves the contract code for each address at the
    specified block.

    ## Parameters
    - `params_list`: A list of maps, each containing:
      - `:block_quantity`: The block number (as a quantity string) at which to fetch the code.
      - `:address`: The address of the contract to fetch the code for.
    - `json_rpc_named_arguments`: A keyword list of JSON-RPC configuration options.

    ## Returns
    - `{:ok, fetched_codes}`, where `fetched_codes` is a `FetchedCodes.t()` struct containing:
      - `params_list`: A list of successfully fetched code parameters, each containing:
        - `address`: The contract address.
        - `block_number`: The block number at which the code was fetched.
        - `code`: The fetched contract code in hexadecimal format.
      - `errors`: A list of errors encountered during the fetch operation.
    - `{:error, reason}`: An error occurred during the fetch operation.
  """
  @spec fetch_codes(
          [%{required(:block_quantity) => quantity, required(:address) => address()}],
          json_rpc_named_arguments
        ) :: {:ok, FetchedCodes.t()} | {:error, reason :: term}
  def fetch_codes(params_list, json_rpc_named_arguments)
      when is_list(params_list) and is_list(json_rpc_named_arguments) do
    id_to_params = id_to_params(params_list)

    with {:ok, responses} <-
           id_to_params
           |> FetchedCodes.requests()
           |> json_rpc(json_rpc_named_arguments) do
      {:ok, FetchedCodes.from_responses(responses, id_to_params)}
    end
  end

  @doc """
    Fetches address nonces for multiple addresses at specified block numbers.

    This function takes a list of parameters, each containing an address and a
    block number, and retrieves the nonce for each address at the specified
    block.

    ## Parameters
    - `params_list`: A list of maps, each containing:
      - `:block_quantity`: The block number (as a quantity string) at which to fetch the nonce.
      - `:address`: The address of the contract to fetch the nonce for.
    - `json_rpc_named_arguments`: A keyword list of JSON-RPC configuration options.

    ## Returns
    - `{:ok, fetched_nonces}`, where `fetched_nonces` is a `Nonces.t()` struct containing:
      - `params_list`: A list of successfully fetched code parameters, each containing:
        - `address`: The contract address.
        - `block_number`: The block number at which the nonce was fetched.
        - `nonce`: The fetched nonce.
      - `errors`: A list of errors encountered during the fetch operation.
    - `{:error, reason}`: An error occurred during the fetch operation.
  """
  @spec fetch_nonces(
          [%{required(:block_quantity) => quantity, required(:address) => address()}],
          json_rpc_named_arguments
        ) :: {:ok, Nonces.t()} | {:error, reason :: term}
  def fetch_nonces(params_list, json_rpc_named_arguments)
      when is_list(params_list) and is_list(json_rpc_named_arguments) do
    id_to_params = id_to_params(params_list)

    with {:ok, responses} <-
           id_to_params
           |> Nonces.requests()
           |> json_rpc(json_rpc_named_arguments) do
      {:ok, Nonces.from_responses(responses, id_to_params)}
    end
  end

  @doc """
  Fetches block reward contract beneficiaries from variant API.
  """
  @spec fetch_beneficiaries([block_number], json_rpc_named_arguments) ::
          {:ok, FetchedBeneficiaries.t()} | {:error, reason :: term} | :ignore
  def fetch_beneficiaries(block_numbers, json_rpc_named_arguments) when is_list(block_numbers) do
    filtered_block_numbers = RangesHelper.filter_traceable_block_numbers(block_numbers)

    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_beneficiaries(
      filtered_block_numbers,
      json_rpc_named_arguments
    )
  end

  @doc """
  Fetches blocks by block hashes.

  Transaction data is included for each block by default.
  Set `with_transactions` parameter to false to exclude tx data.
  """
  @spec fetch_blocks_by_hash([hash()], json_rpc_named_arguments, boolean()) ::
          {:ok, Blocks.t()} | {:error, reason :: term}
  def fetch_blocks_by_hash(block_hashes, json_rpc_named_arguments, with_transactions? \\ true) do
    block_hashes
    |> Enum.map(fn block_hash -> %{hash: block_hash} end)
    |> fetch_blocks_by_params(&Block.ByHash.request(&1, with_transactions?), json_rpc_named_arguments)
  end

  @doc """
  Fetches blocks by block number range.
  """
  @spec fetch_blocks_by_range(Range.t(), json_rpc_named_arguments) :: {:ok, Blocks.t()} | {:error, reason :: term}
  def fetch_blocks_by_range(_first.._last//_ = range, json_rpc_named_arguments) do
    range
    |> Enum.map(fn number -> %{number: number} end)
    |> fetch_blocks_by_params(&Block.ByNumber.request/1, json_rpc_named_arguments)
  end

  @doc """
    Fetches blocks by their block numbers.

    Retrieves block data for a list of block numbers, with optional inclusion of
    transaction data.

    ## Parameters
    - `block_numbers`: List of block numbers to fetch
    - `json_rpc_named_arguments`: Configuration for JSON-RPC connection
    - `with_transactions?`: Whether to include transaction data in blocks (defaults to true)

    ## Returns
    - `{:ok, Blocks.t()}`: Successfully fetched and processed block data
    - `{:error, reason}`: Error occurred during fetch or processing
  """
  @spec fetch_blocks_by_numbers([block_number()], json_rpc_named_arguments(), boolean()) ::
          {:ok, Blocks.t()} | {:error, reason :: term}
  def fetch_blocks_by_numbers(block_numbers, json_rpc_named_arguments, with_transactions? \\ true) do
    block_numbers
    |> Enum.map(fn number -> %{number: number} end)
    |> fetch_blocks_by_params(&Block.ByNumber.request(&1, with_transactions?), json_rpc_named_arguments)
  end

  @doc """
    Fetches a block from the blockchain using a semantic tag identifier.

    ## Parameters
    - `tag`: One of "earliest", "latest", "pending", or "safe" to identify the block
    - `json_rpc_named_arguments`: Configuration for the JSON-RPC connection

    ## Returns
    - `{:ok, Blocks.t()}` - Successfully retrieved block data
    - `{:error, :invalid_tag}` - The provided tag is not recognized
    - `{:error, :not_found}` - No block exists for the given tag
    - `{:error, term()}` - Other errors that occurred during the request
  """
  @spec fetch_block_by_tag(tag(), json_rpc_named_arguments) ::
          {:ok, Blocks.t()} | {:error, reason :: :invalid_tag | :not_found | term()}
  def fetch_block_by_tag(tag, json_rpc_named_arguments) when tag in ~w(earliest latest pending safe) do
    [%{tag: tag}]
    |> fetch_blocks_by_params(&Block.ByTag.request/1, json_rpc_named_arguments)
  end

  @doc """
  Fetches uncle blocks by nephew hashes and indices.
  """
  @spec fetch_uncle_blocks([nephew_index()], json_rpc_named_arguments) :: {:ok, Blocks.t()} | {:error, reason :: term}
  def fetch_uncle_blocks(blocks, json_rpc_named_arguments) do
    blocks
    |> fetch_blocks_by_params(&Block.ByNephew.request/1, json_rpc_named_arguments)
  end

  @doc """
    Fetches chain ID from RPC node using `eth_chainId` JSON-RPC request.

    ## Parameters
    - `json_rpc_named_arguments`: A keyword list of JSON-RPC configuration options.

    ## Returns
    - `{:ok, id}` tuple where `id` is the chain id integer.
    - `{:error, reason}` tuple in case of error.
  """
  @spec fetch_chain_id(json_rpc_named_arguments) :: {:ok, non_neg_integer()} | {:error, reason :: term}
  def fetch_chain_id(json_rpc_named_arguments) do
    result =
      %{id: 0, method: "eth_chainId", params: []}
      |> request()
      |> json_rpc(json_rpc_named_arguments)

    case result do
      {:ok, id} -> {:ok, quantity_to_integer(id)}
      other -> other
    end
  end

  @doc """
    Fetches the block number for a block identified by a semantic tag.

    ## Parameters
    - `tag`: One of "earliest", "latest", "pending", or "safe" to identify the block
    - `json_rpc_named_arguments`: Configuration for the JSON-RPC connection

    ## Returns
    - `{:ok, number}` - Successfully retrieved block number
    - `{:error, :invalid_tag}` - The provided tag is not recognized
    - `{:error, :not_found}` - No block exists for the given tag
    - `{:error, term()}` - Other errors that occurred during the request
  """
  @spec fetch_block_number_by_tag(tag(), json_rpc_named_arguments) ::
          {:ok, non_neg_integer()} | {:error, reason :: :invalid_tag | :not_found | term()}
  def fetch_block_number_by_tag(tag, json_rpc_named_arguments) when tag in ~w(earliest latest pending safe) do
    tag
    |> fetch_block_by_tag(json_rpc_named_arguments)
    |> Block.ByTag.number_from_result()
  end

  @doc """
  Fetches internal transactions from variant API.
  """
  def fetch_internal_transactions(params_list, json_rpc_named_arguments) when is_list(params_list) do
    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_internal_transactions(
      params_list,
      json_rpc_named_arguments
    )
  end

  @doc """
  Fetches internal transactions for entire blocks from variant API.
  """
  def fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments) when is_list(block_numbers) do
    filtered_block_numbers = RangesHelper.filter_traceable_block_numbers(block_numbers)

    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_block_internal_transactions(
      filtered_block_numbers,
      json_rpc_named_arguments
    )
  end

  @doc """
  Retrieves traces from variant API.
  """
  def fetch_first_trace(params_list, json_rpc_named_arguments) when is_list(params_list) do
    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_first_trace(
      params_list,
      json_rpc_named_arguments
    )
  end

  @doc """
  Retrieves Solana transactions that are linked to a given Neon transaction.

  ## Parameters
    - `transaction_hash`: The hash of the Neon transaction
    - `json_rpc_named_arguments`: Named arguments for JSON RPC call

  ## Returns
    - `{:ok, list()}`: List of linked Solana transactions
    - `{:error, reason}`: If the request fails
  """
  @spec get_linked_solana_transactions(
          Explorer.Chain.Hash.t(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:ok, list()} | {:error, reason :: term}
  def get_linked_solana_transactions(transaction_hash, json_rpc_named_arguments) do
    r =
      request(%{
        id: 1,
        method: "neon_getSolanaTransactionByNeonTransaction",
        params: [to_string(transaction_hash)]
      })

    EthereumJSONRPC.json_rpc(r, json_rpc_named_arguments)
  end

  @doc """
  Fetches pending transactions from variant API.
  """
  def fetch_pending_transactions(json_rpc_named_arguments) do
    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_pending_transactions(json_rpc_named_arguments)
  end

  @doc """
  Retrieves raw traces from Ethereum JSON RPC variant API.
  """
  def fetch_transaction_raw_traces(transaction_params, json_rpc_named_arguments) do
    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_transaction_raw_traces(
      transaction_params,
      json_rpc_named_arguments
    )
  end

  @doc """
    Fetches transaction receipts and logs for a list of transactions.

    Makes batch requests to retrieve receipts for multiple transactions and processes
    them into a format suitable for database import.

    ## Parameters
    - `transactions_params`: List of transaction parameter maps, each containing:
      - `gas`: Gas limit for the transaction
      - `hash`: Transaction hash
      - Additional optional parameters
    - `json_rpc_named_arguments`: Configuration for JSON-RPC connection

    ## Returns
    - `{:ok, %{logs: list(), receipts: list()}}` - Successfully processed receipts
      and logs ready for database import
    - `{:error, reason}` - Error occurred during fetch or processing
  """
  @spec fetch_transaction_receipts(
          [
            %{required(:gas) => non_neg_integer(), required(:hash) => hash, optional(atom) => any}
          ],
          json_rpc_named_arguments
        ) :: {:ok, %{logs: list(), receipts: list()}} | {:error, reason :: term}
  def fetch_transaction_receipts(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    Receipts.fetch(transactions_params, json_rpc_named_arguments)
  end

  @doc """
    Assigns a unique integer ID to each set of parameters in the given list.

    This function is used to prepare parameters for batch request-response
    correlation in JSON-RPC calls.

    ## Parameters
    - `params_list`: A list of parameter sets, where each set can be of any type.

    ## Returns
    A map where the keys are integer IDs (starting from 0) and the values are
    the corresponding parameter sets from the input list.

    ## Example
      iex> id_to_params([%{block: 1}, %{block: 2}])
      %{0 => %{block: 1}, 1 => %{block: 2}}
  """
  @spec id_to_params([]) :: %{}
  def id_to_params([]) do
    %{}
  end

  @spec id_to_params([params]) :: %{id => params} when id: non_neg_integer(), params: any()
  def id_to_params(params_list) do
    params_list
    |> Stream.with_index()
    |> Enum.into(%{}, fn {params, id} -> {id, params} end)
  end

  @doc """
   Sanitizes responses by assigning unmatched IDs to responses with missing IDs.

   It handles cases where responses have missing (nil) IDs by assigning them
   unmatched IDs from the id_to_params map.

   ## Parameters
   - `responses`: A list of response maps from a batch JSON-RPC call.
   - `elements_with_ids`: A map or a list enumerating elements with request IDs

   ## Returns
   A list of sanitized response maps where each response has a valid ID.

   ## Example
      iex> responses = [%{id: 1, result: "ok"}, %{id: nil, result: "error"}]
      iex> id_to_params = %{1 => %{}, 2 => %{}, 3 => %{}}
      iex> EthereumJSONRPC.sanitize_responses(responses, id_to_params)
      [%{id: 1, result: "ok"}, %{id: 2, result: "error"}]

      iex> request_ids = [1, 2, 3]
      iex> EthereumJSONRPC.sanitize_responses(responses, request_ids)
      [%{id: 1, result: "ok"}, %{id: 2, result: "error"}]
  """
  @spec sanitize_responses(Transport.batch_response(), %{id => params} | [id]) :: Transport.batch_response()
        when id: EthereumJSONRPC.request_id(), params: any()
  def sanitize_responses(responses, elements_with_ids)

  def sanitize_responses(responses, id_to_params) when is_map(id_to_params) do
    responses
    |> Enum.reduce({[], Map.keys(id_to_params) -- Enum.map(responses, & &1.id)}, &sanitize_responses_reduce_fn/2)
    |> elem(0)
    |> Enum.reverse()
  end

  def sanitize_responses(responses, request_ids) when is_list(request_ids) do
    responses
    |> Enum.reduce({[], request_ids -- Enum.map(responses, & &1.id)}, &sanitize_responses_reduce_fn/2)
    |> elem(0)
    |> Enum.reverse()
  end

  # Processes a single response during sanitization of batch responses.
  #
  # For responses with nil IDs, assigns the next available ID from the unmatched list
  # and logs an error. For responses with valid IDs, simply accumulates them.
  #
  # ## Parameters
  # - `res`: A single response from the batch
  # - `{result_res, non_matched}`: Tuple containing accumulated responses and remaining
  #   unmatched IDs
  #
  # ## Returns
  # - `{result_res, non_matched}`: Updated accumulator tuple with processed response
  @spec sanitize_responses_reduce_fn(Transport.response(), {Transport.batch_response(), [EthereumJSONRPC.request_id()]}) ::
          {Transport.batch_response(), [EthereumJSONRPC.request_id()]}
  defp sanitize_responses_reduce_fn(%{id: nil} = res, {result_res, [id | rest]}) do
    Logger.error(
      "Empty id in response: #{inspect(res)}, stacktrace: #{inspect(Process.info(self(), :current_stacktrace))}"
    )

    {[%{res | id: id} | result_res], rest}
  end

  defp sanitize_responses_reduce_fn(res, {result_res, non_matched}) do
    {[res | result_res], non_matched}
  end

  @doc """
    Executes a JSON-RPC request with the specified transport and options.

    Handles both single requests and batch requests. Uses the RequestCoordinator to
    manage request throttling and retries. If a fallback URL is configured, it may
    switch to it when the primary endpoint is unavailable.

    ## Parameters
    - `request`: A single request map or list of request maps to execute
    - `named_arguments`: Configuration options including:
      - `:transport`: The transport module to use (e.g. HTTP, WebSocket)
      - `:transport_options`: Options for the transport including URLs
      - `:throttle_timeout`: Maximum time to wait for throttled requests

    ## Returns
    - `{:ok, result}` on success with the JSON-RPC response
    - `{:error, reason}` if the request fails
  """
  @spec json_rpc(Transport.request(), json_rpc_named_arguments) ::
          {:ok, Transport.result()} | {:error, reason :: term()}
  @spec json_rpc(Transport.batch_request(), json_rpc_named_arguments) ::
          {:ok, Transport.batch_response()} | {:error, reason :: term()}
  def json_rpc(request, named_arguments) when (is_map(request) or is_list(request)) and is_list(named_arguments) do
    transport = Keyword.fetch!(named_arguments, :transport)
    transport_options = Keyword.fetch!(named_arguments, :transport_options)
    throttle_timeout = Keyword.get(named_arguments, :throttle_timeout, @default_throttle_timeout)

    url = maybe_replace_url(transport_options[:url], transport_options[:fallback_url], transport)
    corrected_transport_options = Keyword.replace(transport_options, :url, url)

    case RequestCoordinator.perform(request, transport, corrected_transport_options, throttle_timeout) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        maybe_inc_error_count(corrected_transport_options[:url], named_arguments, transport)
        {:error, reason}
    end
  end

  defp do_balances_request(id_to_params, _chunk_size, _args) when id_to_params == %{}, do: {:ok, []}

  defp do_balances_request(id_to_params, chunk_size, json_rpc_named_arguments) do
    id_to_params
    |> FetchedBalances.requests()
    |> chunk_requests(chunk_size)
    |> json_rpc(json_rpc_named_arguments)
  end

  defp archive_json_rpc_named_arguments(json_rpc_named_arguments) do
    CommonHelper.put_in_keyword_nested(
      json_rpc_named_arguments,
      [:transport_options, :method_to_url, :eth_getBalance],
      :trace
    )
  end

  defp maybe_request_archive_balances(id_to_params, trace_url_used?, disabled?, chunk_size, json_rpc_named_arguments) do
    if not trace_url_used? and not disabled? do
      do_balances_request(id_to_params, chunk_size, archive_json_rpc_named_arguments(json_rpc_named_arguments))
    else
      {:ok, []}
    end
  end

  # Replaces the URL with a fallback URL for non-HTTP transports.
  @spec maybe_replace_url(String.t(), String.t(), Transport.t()) :: String.t()
  defp maybe_replace_url(url, _replace_url, EthereumJSONRPC.HTTP), do: url
  defp maybe_replace_url(url, replace_url, _), do: EndpointAvailabilityObserver.maybe_replace_url(url, replace_url, :ws)

  # Increments error count for non-HTTP transports when endpoint errors occur
  @spec maybe_inc_error_count(String.t(), EthereumJSONRPC.json_rpc_named_arguments(), Transport.t()) :: :ok
  defp maybe_inc_error_count(_url, _arguments, EthereumJSONRPC.HTTP), do: :ok
  defp maybe_inc_error_count(url, arguments, _), do: EndpointAvailabilityObserver.inc_error_count(url, arguments, :ws)

  @doc """
  Converts `t:quantity/0` to `t:non_neg_integer/0`.
  """
  @spec quantity_to_integer(quantity) :: non_neg_integer() | nil
  def quantity_to_integer("0x" <> hexadecimal_digits) do
    String.to_integer(hexadecimal_digits, 16)
  end

  def quantity_to_integer(integer) when is_integer(integer), do: integer

  def quantity_to_integer(string) when is_binary(string) do
    case Integer.parse(string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  def quantity_to_integer(_), do: nil

  @doc """
  Sanitizes ID in JSON RPC request following JSON RPC [spec](https://www.jsonrpc.org/specification#request_object:~:text=An%20identifier%20established%20by%20the%20Client%20that%20MUST%20contain%20a%20String%2C%20Number%2C%20or%20NULL%20value%20if%20included.%20If%20it%20is%20not%20included%20it%20is%20assumed%20to%20be%20a%20notification.%20The%20value%20SHOULD%20normally%20not%20be%20Null%20%5B1%5D%20and%20Numbers%20SHOULD%20NOT%20contain%20fractional%20parts%20%5B2%5D).
  """
  @spec sanitize_id(quantity) :: non_neg_integer() | String.t() | nil

  def sanitize_id(integer) when is_integer(integer), do: integer

  def sanitize_id(string) when is_binary(string) do
    # match ID string and ID string without non-ASCII characters
    if string == for(<<c <- string>>, c < 128, into: "", do: <<c>>) do
      string
    else
      nil
    end
  end

  def sanitize_id(_), do: nil

  @doc """
  Converts `t:non_neg_integer/0` to `t:quantity/0`
  """
  @spec integer_to_quantity(non_neg_integer | binary) :: quantity
  def integer_to_quantity(integer) when is_integer(integer) and integer >= 0 do
    "0x" <> Integer.to_string(integer, 16)
  end

  def integer_to_quantity(integer) when is_binary(integer) do
    integer
  end

  @doc """
    Creates a JSON-RPC 2.0 request payload from the provided map.

    ## Parameters
    - `map`: A map containing:
      - `id`: Request identifier
      - `method`: Name of the JSON-RPC method to call
      - `params`: List of parameters to pass to the method

    ## Returns
    - A JSON-RPC 2.0 compliant request map with the "jsonrpc" field added
  """
  @spec request(%{id: request_id, method: String.t(), params: list()}) :: Transport.request()
  def request(%{method: method, params: params} = map)
      when is_binary(method) and is_list(params) do
    Map.put(map, :jsonrpc, "2.0")
  end

  @doc """
  Subscribes to `t:EthereumJSONRPC.Subscription.event/0` with `t:EthereumJSONRPC.Subscription.params/0`.

  Events are delivered in a tuple tagged with the `t:EthereumJSONRPC.Subscription.t/0` and containing the same output
  as the single-request form of `json_rpc/2`.

  | Message                                                                           | Description                            |
  |-----------------------------------------------------------------------------------|----------------------------------------|
  | `{EthereumJSONRPC.Subscription.t(), {:ok, EthereumJSONRPC.Transport.result.t()}}` | New result in subscription             |
  | `{EthereumJSONRPC.Subscription.t(), {:error, reason :: term()}}`                  | There was an error in the subscription |

  Subscription can be canceled by calling `unsubscribe/1` with the returned `t:EthereumJSONRPC.Subscription.t/0`.
  """
  @spec subscribe(event :: Subscription.event(), params :: Subscription.params(), subscribe_named_arguments) ::
          {:ok, Subscription.t()} | {:error, reason :: term()}
  def subscribe(event, params \\ [], named_arguments) when is_list(params) do
    transport = Keyword.fetch!(named_arguments, :transport)
    transport_options = Keyword.fetch!(named_arguments, :transport_options)

    transport.subscribe(event, params, transport_options)
  end

  @doc """
  Unsubscribes to `t:EthereumJSONRPC.Subscription.t/0` created with `subscribe/2`.

  ## Returns

   * `:ok` - subscription was canceled
   * `{:error, :not_found}` - subscription could not be canceled.  It did not exist because either the server already
       canceled it, it never existed, or `unsubscribe/1 ` was called on it before.
   * `{:error, reason :: term}` - other error cancelling subscription.

  """
  @spec unsubscribe(Subscription.t()) :: :ok | {:error, reason :: term()}
  def unsubscribe(%Subscription{transport: transport} = subscription) do
    transport.unsubscribe(subscription)
  end

  # We can only depend on implementations supporting 64-bit integers:
  # * Ganache only supports u32 (https://github.com/trufflesuite/ganache-core/issues/190)
  def unique_request_id do
    <<unique_request_id::big-integer-size(4)-unit(8)>> = :crypto.strong_rand_bytes(4)
    unique_request_id
  end

  @doc """
  Converts `t:timestamp/0` to `t:DateTime.t/0`
  """
  def timestamp_to_datetime(timestamp) do
    case quantity_to_integer(timestamp) do
      nil ->
        nil

      quantity ->
        Timex.from_unix(quantity)
    end
  end

  # Fetches block data using the provided parameters and request function.
  #
  # Assigns unique IDs to each parameter set, generates JSON-RPC requests using the
  # provided request function, executes them, and processes the responses into a
  # structured format.
  #
  # ## Parameters
  # - `params`: List of parameter maps for block requests
  # - `request`: Function that takes a parameter map and returns a JSON-RPC request
  # - `json_rpc_named_arguments`: Configuration for JSON-RPC connection
  #
  # ## Returns
  # - `{:ok, Blocks.t()}`: Successfully fetched and processed block data
  # - `{:error, reason}`: Error occurred during fetch or processing
  @spec fetch_blocks_by_params([map()], function(), json_rpc_named_arguments()) ::
          {:ok, Blocks.t()} | {:error, reason :: term()}
  defp fetch_blocks_by_params(params, request, json_rpc_named_arguments)
       when is_list(params) and is_function(request, 1) do
    id_to_params = id_to_params(params)

    with {:ok, responses} <-
           id_to_params
           |> Blocks.requests(request)
           |> json_rpc(json_rpc_named_arguments) do
      {:ok, Blocks.from_responses(responses, id_to_params)}
    end
  end

  defp chunk_requests(requests, nil), do: requests
  defp chunk_requests(requests, chunk_size), do: Enum.chunk_every(requests, chunk_size)

  def put_if_present(result, transaction, keys) do
    Enum.reduce(keys, result, fn key, acc ->
      key_list = key |> Tuple.to_list()
      from_key = Enum.at(key_list, 0)
      to_key = Enum.at(key_list, 1)
      opts = if Enum.count(key_list) > 2, do: Enum.at(key_list, 2), else: %{}

      value = transaction[from_key] || opts[:default]

      validate_key(acc, to_key, value, opts)
    end)
  end

  defp validate_key(acc, _to_key, nil, _opts), do: acc

  defp validate_key(acc, to_key, value, %{:validation => validation}) do
    case validation do
      :address_hash ->
        if address_correct?(value), do: Map.put(acc, to_key, value), else: acc

      _ ->
        Map.put(acc, to_key, value)
    end
  end

  defp validate_key(acc, to_key, value, _validation) do
    Map.put(acc, to_key, value)
  end

  # todo: The similar function exists in Indexer application:
  # Here is the room for future refactoring to keep a single function.
  @spec address_correct?(binary()) :: boolean()
  defp address_correct?(address) when is_binary(address) do
    String.match?(address, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  defp address_correct?(_address) do
    false
  end
end
