defmodule EthereumJSONRPC do
  @moduledoc """
  Ethereum JSONRPC client.

  ## Configuration

  Configuration for parity URLs can be provided with the following mix config:

      config :ethereum_jsonrpc,
        url: "https://sokol.poa.network",
        trace_url: "https://sokol-trace.poa.network",
        http: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]

  Note: the tracing node URL is provided separately from `:url`, via `:trace_url`. The trace URL and is used for
  `fetch_internal_transactions`, which is only a supported method on tracing nodes. The `:http` option is passed
  directly to the HTTP library (`HTTPoison`), which forwards the options down to `:hackney`.
  """

  require Logger

  alias Explorer.Chain.Block
  alias EthereumJSONRPC.{Blocks, Parity, Receipts, Transactions}

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

  @doc """
  Fetches configuration for this module under `key`

  Configuration can be set a compile time using `config`

      config :ethereume_jsonrpc, key, value

  Configuration can be set a runtime using `Application.put_env/3`

      Application.put_env(:ethereume_jsonrpc, key, value)

  """
  def config(key) do
    Application.fetch_env!(:ethereum_jsonrpc, key)
  end

  @doc """
  Fetches balance for each address `hash` at the `block_number`
  """
  @spec fetch_balances([%{required(:block_quantity) => quantity, required(:hash_data) => data()}]) ::
          {:ok,
           [
             %{
               required(:fetched_balance) => non_neg_integer(),
               required(:fetched_balance_block_number) => Block.block_number(),
               required(:hash) => quantity
             }
           ]}
          | {:error, reason :: term}
  def fetch_balances(params_list) when is_list(params_list) do
    id_to_params = id_to_params(params_list)

    with {:ok, responses} <-
           id_to_params
           |> get_balance_requests()
           |> json_rpc(config(:trace_url)) do
      get_balance_responses_to_addresses_params(responses, id_to_params)
    end
  end

  @doc """
  Fetches blocks by block hashes.

  Transaction data is included for each block.
  """
  def fetch_blocks_by_hash(block_hashes) do
    block_hashes
    |> get_block_by_hash_requests()
    |> json_rpc(config(:url))
    |> handle_get_blocks()
    |> case do
      {:ok, _next, results} -> {:ok, results}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches blocks by block number range.
  """
  def fetch_blocks_by_range(_first.._last = range) do
    range
    |> get_block_by_number_requests()
    |> json_rpc(config(:url))
    |> handle_get_blocks()
  end

  @doc """
  Fetches block number by `t:tag/0`.

  The `"earliest"` tag is the earlist block number, which is `0`.

      iex> EthereumJSONRPC.fetch_block_number_by_tag("earliest")
      {:ok, 0}

  ## Returns

   * `{:ok, number}` - the block number for the given `tag`.
   * `{:error, :invalid_tag}` - When `tag` is not a valid `t:tag/0`.
   * `{:error, reason}` - other JSONRPC error.

  """
  @spec fetch_block_number_by_tag(tag()) :: {:ok, non_neg_integer()} | {:error, reason :: :invalid_tag | term()}
  def fetch_block_number_by_tag(tag) when tag in ~w(earliest latest pending) do
    tag
    |> get_block_by_tag_request()
    |> json_rpc(config(:url))
    |> handle_get_block_by_tag()
  end

  @doc """
  Fetches internal transactions from client-specific API.
  """
  def fetch_internal_transactions(params_list) when is_list(params_list) do
    Parity.fetch_internal_transactions(params_list)
  end

  def fetch_transaction_receipts(hashes) when is_list(hashes) do
    Receipts.fetch(hashes)
  end

  @doc """
  Assigns an id to each set of params in `params_list` for batch request-response correlation
  """
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
    * `{:error, reason}` if POST failes
  """
  def json_rpc(payload, url) when is_list(payload) do
    chunked_json_rpc(url, [payload], config(:http), [])
  end

  def json_rpc(payload, url) do
    json = encode_json(payload)

    case post(url, json, config(:http)) do
      {:ok, %HTTPoison.Response{body: body, status_code: code}} ->
        body |> decode_json(code, json, url) |> handle_response(code)

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Converts `t:nonce/0` to `t:non_neg_integer/0`
  """
  @spec nonce_to_integer(nonce) :: non_neg_integer()
  def nonce_to_integer(nonce) do
    quantity_to_integer(nonce)
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
  @spec request(%{id: term, method: String.t(), params: list()}) :: %{String.t() => term}
  def request(%{id: id, method: method, params: params}) do
    %{
      "id" => id,
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
    }
  end

  @doc """
  Converts `t:timestamp/0` to `t:DateTime.t/0`
  """
  def timestamp_to_datetime(timestamp) do
    timestamp
    |> quantity_to_integer()
    |> Timex.from_unix()
  end

  defp chunked_json_rpc(_url, [], _options, decoded_response_bodies) when is_list(decoded_response_bodies) do
    list =
      decoded_response_bodies
      |> Enum.reverse()
      |> List.flatten()

    {:ok, list}
  end

  defp chunked_json_rpc(url, [batch | tail] = chunks, options, decoded_response_bodies)
       when is_list(batch) and is_list(tail) and is_list(decoded_response_bodies) do
    json = encode_json(batch)

    case post(url, json, options) do
      {:ok, %HTTPoison.Response{status_code: 413} = response} ->
        rechunk_json_rpc(url, chunks, options, response, decoded_response_bodies)

      {:ok, %HTTPoison.Response{body: body, status_code: status_code}} ->
        decoded_body = decode_json(body, status_code, json, url)
        chunked_json_rpc(url, tail, options, [decoded_body | decoded_response_bodies])

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp rechunk_json_rpc(url, [batch | tail], options, response, decoded_response_bodies) do
    case length(batch) do
      # it can't be made any smaller
      1 ->
        Logger.error(fn ->
          "413 Request Entity Too Large returned from single request batch.  Cannot shrink batch further."
        end)

        {:error, response}

      batch_size ->
        split_size = div(batch_size, 2)
        {first_chunk, second_chunk} = Enum.split(batch, split_size)
        new_chunks = [first_chunk, second_chunk | tail]
        chunked_json_rpc(url, new_chunks, options, decoded_response_bodies)
    end
  end

  defp get_balance_requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{block_quantity: block_quantity, hash_data: hash_data}} ->
      get_balance_request(%{id: id, block_quantity: block_quantity, hash_data: hash_data})
    end)
  end

  defp get_balance_request(%{id: id, block_quantity: block_quantity, hash_data: hash_data}) do
    request(%{id: id, method: "eth_getBalance", params: [hash_data, block_quantity]})
  end

  defp get_balance_responses_to_addresses_params(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    {status, reversed} =
      responses
      |> Enum.map(&get_balance_response_to_address_params(&1, id_to_params))
      |> Enum.reduce(
        {:ok, []},
        fn
          {:ok, address_params}, {:ok, address_params_list} ->
            {:ok, [address_params | address_params_list]}

          {:ok, _}, {:error, _} = acc_error ->
            acc_error

          {:error, reason}, {:ok, _} ->
            {:error, [reason]}

          {:error, reason}, {:error, acc_reason} ->
            {:error, [reason | acc_reason]}
        end
      )

    {status, Enum.reverse(reversed)}
  end

  defp get_balance_response_to_address_params(%{"id" => id, "result" => fetched_balance_quantity}, id_to_params)
       when is_map(id_to_params) do
    %{block_quantity: block_quantity, hash_data: hash_data} = Map.fetch!(id_to_params, id)

    {:ok,
     %{
       fetched_balance: quantity_to_integer(fetched_balance_quantity),
       fetched_balance_block_number: quantity_to_integer(block_quantity),
       hash: hash_data
     }}
  end

  defp get_balance_response_to_address_params(%{"id" => id, "error" => error}, id_to_params)
       when is_map(id_to_params) do
    %{block_quantity: block_quantity, hash_data: hash_data} = Map.fetch!(id_to_params, id)

    annotated_error = Map.merge(error, %{"blockNumber" => block_quantity, "hash" => hash_data})

    {:error, annotated_error}
  end

  defp get_block_by_hash_requests(block_hashes) do
    for block_hash <- block_hashes do
      get_block_by_hash_request(%{id: block_hash, hash: block_hash, transactions: :full})
    end
  end

  defp get_block_by_hash_request(%{id: id} = options) do
    request(%{id: id, method: "eth_getBlockByHash", params: get_block_by_hash_params(options)})
  end

  defp get_block_by_hash_params(%{hash: hash} = options) do
    [hash, get_block_transactions(options)]
  end

  defp get_block_by_number_requests(range) do
    for current <- range do
      get_block_by_number_request(%{id: current, quantity: current, transactions: :full})
    end
  end

  defp get_block_by_number_request(%{id: id} = options) do
    request(%{id: id, method: "eth_getBlockByNumber", params: get_block_by_number_params(options)})
  end

  defp get_block_by_tag_request(tag) do
    # eth_getBlockByNumber accepts either a number OR a tag
    get_block_by_number_request(%{id: tag, tag: tag, transactions: :hashes})
  end

  defp get_block_by_number_params(options) do
    [get_block_by_number_subject(options), get_block_transactions(options)]
  end

  defp get_block_by_number_subject(options) do
    case {Map.fetch(options, :quantity), Map.fetch(options, :tag)} do
      {{:ok, integer}, :error} when is_integer(integer) ->
        integer_to_quantity(integer)

      {:error, {:ok, tag}} ->
        tag

      {{:ok, _}, {:ok, _}} ->
        raise ArgumentError, "Only one of :quantity or :tag can be passed to get_block_by_number_request"

      {:error, :error} ->
        raise ArgumentError, "One of :quantity or :tag MUST be passed to get_block_by_number_request"
    end
  end

  defp get_block_transactions(%{transactions: transactions}) do
    case transactions do
      :full -> true
      :hashes -> false
    end
  end

  defp encode_json(data), do: Jason.encode_to_iodata!(data)

  defp decode_json(response_body, response_status_code, request_body, request_url) do
    Jason.decode!(response_body)
  rescue
    Jason.DecodeError ->
      Logger.error(fn ->
        """
        failed to decode json payload:

            request url: #{inspect(request_url)}

            request body: #{inspect(request_body)}

            response status code: #{inspect(response_status_code)}

            response body: #{inspect(response_body)}
        """
      end)

      raise("bad jason")
  end

  defp handle_get_blocks({:ok, results}) do
    {blocks, next} =
      Enum.reduce(results, {[], :more}, fn
        %{"result" => nil}, {blocks, _} -> {blocks, :end_of_chain}
        %{"result" => %{} = block}, {blocks, next} -> {[block | blocks], next}
      end)

    elixir_blocks = Blocks.to_elixir(blocks)
    elixir_transactions = Blocks.elixir_to_transactions(elixir_blocks)
    blocks_params = Blocks.elixir_to_params(elixir_blocks)
    transactions_params = Transactions.elixir_to_params(elixir_transactions)

    {:ok, next,
     %{
       blocks: blocks_params,
       transactions: transactions_params
     }}
  end

  defp handle_get_blocks({:error, _} = error), do: error

  defp handle_get_block_by_tag({:ok, %{"number" => quantity}}) do
    {:ok, quantity_to_integer(quantity)}
  end

  defp handle_get_block_by_tag({:error, %{"code" => -32602}}), do: {:error, :invalid_tag}
  defp handle_get_block_by_tag({:error, _} = error), do: error

  defp handle_response(resp, 200) do
    case resp do
      %{"error" => error} -> {:error, error}
      %{"result" => result} -> {:ok, result}
    end
  end

  defp handle_response(resp, _status) do
    {:error, resp}
  end

  defp post(url, json, options) do
    HTTPoison.post(url, json, [{"Content-Type", "application/json"}], options)
  end
end
