defmodule EthereumJSONRPC do
  @moduledoc """
  Ethereum JSONRPC client.

  ## Configuration

  Configuration for parity URLs can be provided with the following mix config:

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
    FetchedBalances,
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
  Binary data encoded as a single hexadecimal number in a `String.t`
  """
  @type data :: String.t()

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
  @spec execute_contract_functions(
          [%{contract_address: String.t(), data: String.t(), id: String.t()}],
          json_rpc_named_arguments,
          [{:block_number, non_neg_integer()}]
        ) :: {:ok, list()} | {:error, term()}
  def execute_contract_functions(functions, json_rpc_named_arguments, opts \\ []) do
    block_number = Keyword.get(opts, :block_number)

    functions
    |> Enum.map(&build_eth_call_payload(&1, block_number))
    |> json_rpc(json_rpc_named_arguments)
  end

  defp build_eth_call_payload(
         %{contract_address: address, data: data, id: id},
         nil = _block_number
       ) do
    params = [%{to: address, data: data}, "latest"]
    request(%{id: id, method: "eth_call", params: params})
  end

  defp build_eth_call_payload(
         %{contract_address: address, data: data, id: id},
         block_number
       ) do
    params = [%{to: address, data: data}, integer_to_quantity(block_number)]
    request(%{id: id, method: "eth_call", params: params})
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
    id_to_params = id_to_params(params_list)

    with {:ok, responses} <-
           id_to_params
           |> FetchedBalances.requests()
           |> json_rpc(json_rpc_named_arguments) do
      {:ok, FetchedBalances.from_responses(responses, id_to_params)}
    end
  end

  @doc """
  Fetches block reward contract beneficiaries from variant API.
  """
  def fetch_beneficiaries(_first.._last = range, json_rpc_named_arguments) do
    Keyword.fetch!(json_rpc_named_arguments, :variant).fetch_beneficiaries(range, json_rpc_named_arguments)
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
  @spec quantity_to_integer(quantity) :: non_neg_integer()
  def quantity_to_integer("0x" <> hexadecimal_digits) do
    String.to_integer(hexadecimal_digits, 16)
  end

  @doc """
  Converts `t:non_neg_integer/0` to `t:quantity/0`
  """
  @spec integer_to_quantity(non_neg_integer) :: quantity
  def integer_to_quantity(integer) when is_integer(integer) and integer >= 0 do
    "0x" <> Integer.to_string(integer, 16)
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
  # * Parity only supports u64 (https://github.com/paritytech/jsonrpc-core/blob/f2c61edb817e344d92ab3baf872fa77d1602430a/src/id.rs#L13)
  # * Ganache only supports u32 (https://github.com/trufflesuite/ganache-core/issues/190)
  def unique_request_id do
    <<unique_request_id::big-integer-size(4)-unit(8)>> = :crypto.strong_rand_bytes(4)
    unique_request_id
  end

  @doc """
  Converts `t:timestamp/0` to `t:DateTime.t/0`
  """
  def timestamp_to_datetime(timestamp) do
    timestamp
    |> quantity_to_integer()
    |> Timex.from_unix()
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
end
