defmodule EthereumJSONRPC do
  @moduledoc """
  Ethereum JSONRPC client.

  ## Configuration

  Configuration for Nethermind URLs can be provided with the following mix config:

      config :ethereum_jsonrpc,
        url: "http://localhost:8545",
        trace_url: "http://localhost:8545",
        http: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]


  Note: the tracing node URL is provided separately from `:url`, via `:trace_url`. The trace URL and is used for
  `fetch_internal_transactions`, which is only a supported method on tracing nodes. The `:http` option is passed
  directly to the HTTP library (`HTTPoison`), which forwards the options down to `:hackney`.

  ## Throttling

  Requests for fetching blockchain can put a lot of CPU pressure on JSON RPC
  nodes. EthereumJSONRPC will check for request timeouts as well as bad-gateway
  responses and add delay between requests until the JSON RPC nodes reach
  stability. For finer tuning and configuration of throttling, read the
  documentation for `EthereumJSONRPC.RequestCoordinator`.
  """

  alias EthereumJSONRPC.{
    Block,
    Blocks,
    Contract,
    FetchedBalances,
    FetchedBeneficiaries,
    FetchedCodes,
    Receipts,
    RequestCoordinator,
    Subscription,
    Transport,
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
   * `:throttle_timout` - the maximum amount of time in milliseconds to throttle
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
    if Enum.count(functions) > 0 do
      Contract.execute_contract_functions(functions, abi, json_rpc_named_arguments, leave_error_as_map)
    else
      []
    end
  end

  @spec execute_contract_functions_by_name([Contract.call_by_name()], [map()], json_rpc_named_arguments) :: [
          Contract.call_result()
        ]
  def execute_contract_functions_by_name(functions, abi, json_rpc_named_arguments) do
    Contract.execute_contract_functions_by_name(functions, abi, json_rpc_named_arguments)
  end

  @doc """
  Fetches balance for each address `hash` at the `block_number`
  """
  @spec fetch_balances(
          [%{required(:block_quantity) => quantity, required(:hash_data) => data()}],
          json_rpc_named_arguments
        ) :: {:ok, FetchedBalances.t()} | {:error, reason :: term}
  def fetch_balances(params_list, json_rpc_named_arguments)
      when is_list(params_list) and is_list(json_rpc_named_arguments) do
    filtered_params =
      if Application.get_env(:ethereum_jsonrpc, :disable_archive_balances?) do
        params_list
        |> Enum.filter(fn
          %{block_quantity: "latest"} -> true
          _ -> false
        end)
      else
        params_list
      end

    id_to_params = id_to_params(filtered_params)

    with {:ok, responses} <-
           id_to_params
           |> FetchedBalances.requests()
           |> json_rpc(json_rpc_named_arguments) do
      {:ok, FetchedBalances.from_responses(responses, id_to_params)}
    end
  end

  @doc """
  Fetches code for each given `address` at the `block_number`.
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
  Fetches block reward contract beneficiaries from variant API.
  """
  @spec fetch_beneficiaries([block_number], json_rpc_named_arguments) ::
          {:ok, FetchedBeneficiaries.t()} | {:error, reason :: term} | :ignore
  def fetch_beneficiaries(block_numbers, json_rpc_named_arguments) when is_list(block_numbers) do
    filtered_block_numbers = block_numbers_in_range(block_numbers)

    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_beneficiaries(
      filtered_block_numbers,
      json_rpc_named_arguments
    )
  end

  @doc """
  Fetches blocks by block hashes.

  Transaction data is included for each block.
  """
  @spec fetch_blocks_by_hash([hash()], json_rpc_named_arguments) :: {:ok, Blocks.t()} | {:error, reason :: term}
  def fetch_blocks_by_hash(block_hashes, json_rpc_named_arguments) do
    block_hashes
    |> Enum.map(fn block_hash -> %{hash: block_hash} end)
    |> fetch_blocks_by_params(&Block.ByHash.request/1, json_rpc_named_arguments)
  end

  @doc """
  Fetches blocks by block number range.
  """
  @spec fetch_blocks_by_range(Range.t(), json_rpc_named_arguments) :: {:ok, Blocks.t()} | {:error, reason :: term}
  def fetch_blocks_by_range(_first.._last = range, json_rpc_named_arguments) do
    range
    |> Enum.map(fn number -> %{number: number} end)
    |> fetch_blocks_by_params(&Block.ByNumber.request/1, json_rpc_named_arguments)
  end

  @doc """
  Fetches uncle blocks by nephew hashes and indices.
  """
  @spec fetch_uncle_blocks([nephew_index()], json_rpc_named_arguments) :: {:ok, Blocks.t()} | {:error, reason :: term}
  def fetch_uncle_blocks(blocks, json_rpc_named_arguments) do
    blocks
    |> fetch_blocks_by_params(&Block.ByNephew.request/1, json_rpc_named_arguments)
  end

  @spec fetch_net_version(json_rpc_named_arguments) :: {:ok, non_neg_integer()} | {:error, reason :: term}
  def fetch_net_version(json_rpc_named_arguments) do
    result =
      %{id: 0, method: "net_version", params: []}
      |> request()
      |> json_rpc(json_rpc_named_arguments)

    case result do
      {:ok, bin_number} -> {:ok, String.to_integer(bin_number)}
      other -> other
    end
  end

  @doc """
  Fetches block number by `t:tag/0`.

  ## Returns

   * `{:ok, number}` - the block number for the given `tag`.
   * `{:error, :invalid_tag}` - When `tag` is not a valid `t:tag/0`.
   * `{:error, reason}` - other JSONRPC error.

  """
  @spec fetch_block_number_by_tag(tag(), json_rpc_named_arguments) ::
          {:ok, non_neg_integer()} | {:error, reason :: :invalid_tag | :not_found | term()}
  def fetch_block_number_by_tag(tag, json_rpc_named_arguments) when tag in ~w(earliest latest pending) do
    %{id: 0, tag: tag}
    |> Block.ByTag.request()
    |> json_rpc(json_rpc_named_arguments)
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
    filtered_block_numbers = block_numbers_in_range(block_numbers)

    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_block_internal_transactions(
      filtered_block_numbers,
      json_rpc_named_arguments
    )
  end

  def block_numbers_in_range(block_numbers) do
    min_block = first_block_to_fetch(:trace_first_block)

    block_numbers
    |> Enum.filter(fn block_number ->
      block_number >= min_block
    end)
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
  Fetches pending transactions from variant API.
  """
  def fetch_pending_transactions(json_rpc_named_arguments) do
    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_pending_transactions(json_rpc_named_arguments)
  end

  @spec fetch_transaction_receipts(
          [
            %{required(:gas) => non_neg_integer(), required(:hash) => hash, optional(atom) => any}
          ],
          json_rpc_named_arguments
        ) :: {:ok, %{logs: list(), receipts: list()}} | {:error, reason :: term}
  def fetch_transaction_receipts(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    Receipts.fetch(transactions_params, json_rpc_named_arguments)
  end

  def fetch_logs(from..to, json_rpc_named_arguments) do
    Receipts.fetch_logs(from, to, json_rpc_named_arguments)
  end

  @doc """
  Assigns an id to each set of params in `params_list` for batch request-response correlation
  """
  @spec id_to_params([params]) :: %{id => params} when id: non_neg_integer(), params: map()
  def id_to_params(params_list) do
    params_list
    |> Stream.with_index()
    |> Enum.into(%{}, fn {params, id} -> {id, params} end)
  end

  @doc """
    1. POSTs JSON `payload` to `url`
    2. Decodes the response
    3. Handles the response

  ## Returns

    * Handled response
    * `{:error, reason}` if POST fails
  """
  @spec json_rpc(Transport.request(), json_rpc_named_arguments) ::
          {:ok, Transport.result()} | {:error, reason :: term()}
  @spec json_rpc(Transport.batch_request(), json_rpc_named_arguments) ::
          {:ok, Transport.batch_response()} | {:error, reason :: term()}
  def json_rpc(request, named_arguments) when (is_map(request) or is_list(request)) and is_list(named_arguments) do
    transport = Keyword.fetch!(named_arguments, :transport)
    transport_options = Keyword.fetch!(named_arguments, :transport_options)
    throttle_timeout = Keyword.get(named_arguments, :throttle_timeout, @default_throttle_timeout)
    RequestCoordinator.perform(request, transport, transport_options, throttle_timeout)
  end

  @doc """
  Converts `t:quantity/0` to `t:non_neg_integer/0`.
  """
  @spec quantity_to_integer(quantity) :: non_neg_integer() | :error
  def quantity_to_integer("0x" <> hexadecimal_digits) do
    String.to_integer(hexadecimal_digits, 16)
  end

  def quantity_to_integer(integer) when is_integer(integer), do: integer

  def quantity_to_integer(string) when is_binary(string) do
    case Integer.parse(string) do
      {integer, ""} -> integer
      _ -> :error
    end
  end

  @doc """
  Converts `t:non_neg_integer/0` to `t:quantity/0`
  """
  @spec integer_to_quantity(integer) :: quantity
  def integer_to_quantity(integer) when is_integer(integer) and integer >= 0 do
    "0x" <> Integer.to_string(integer, 16)
  end

  def integer_to_quantity(integer) when is_integer(integer) do
    Integer.to_string(integer, 10)
  end

  @doc """
  A request payload for a JSONRPC.
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
      :error ->
        nil

      quantity ->
        Timex.from_unix(quantity)
    end
  end

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

  def first_block_to_fetch(config) do
    string_value = Application.get_env(:indexer, config)

    case Integer.parse(string_value) do
      {integer, ""} -> integer
      _ -> 0
    end
  end
end
