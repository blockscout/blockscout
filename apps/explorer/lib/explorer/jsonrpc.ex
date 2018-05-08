defmodule Explorer.JSONRPC do
  @moduledoc """
  Ethereum JSONRPC client.

  ## Configuration

  Configuration for parity URLs can be provided with the following mix config:

      config :explorer, Explorer.JSONRPC,
        url: "https://sokol.poa.network",
        trace_url: "https://sokol-trace.poa.network",
        http: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :eth]]

  Note: the tracing node URL is provided separately from `:url`, via `:trace_url`. The trace URL and is used for
  `fetch_internal_transactions`, which is only a supported method on tracing nodes. The `:http` option is passed
  directly to the HTTP library (`HTTPoison`), which forwards the options down to `:hackney`.
  """

  require Logger

  alias Explorer.JSONRPC.{Blocks, Parity, Receipts, Transactions}

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
  Unix timestamp encoded as a hexadecimal number in a `String.t`
  """
  @type timestamp :: String.t()

  def child_spec(_opts) do
    :hackney_pool.child_spec(:eth, recv_timeout: 60_000, timeout: 60_000, max_connections: 1000)
  end

  @doc """
  Lists changes for a given filter subscription.
  """
  def check_for_updates(filter_id) do
    request = %{
      "id" => filter_id,
      "jsonrpc" => "2.0",
      "method" => "eth_getFilterChanges",
      "params" => [filter_id]
    }

    json_rpc(request, config(:url))
  end

  @doc """
  Fetches configuration for this module under `key`

  Configuration can be set a compile time using `config`

      config :explorer, Explorer.JSONRRPC, key: value

  Configuration can be set a runtime using `Application.put_env/3`

      Application.put_env(:explorer, Explorer.JSONRPC, key: value)

  """
  def config(key) do
    :explorer
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end

  @doc """
  Fetches address balances by address hashes.
  """
  def fetch_balances_by_hash(address_hashes) do
    batched_requests =
      for hash <- address_hashes do
        %{
          "id" => hash,
          "jsonrpc" => "2.0",
          "method" => "eth_getBalance",
          "params" => [hash, "latest"]
        }
      end

    batched_requests
    |> json_rpc(config(:url))
    |> handle_balances()
  end

  defp handle_balances({:ok, results}) do
    native_results =
      for response <- results, into: %{} do
        {response["id"], hexadecimal_to_integer(response["result"])}
      end

    {:ok, native_results}
  end

  defp handle_balances({:error, _reason} = err), do: err

  @doc """
  Fetches blocks by block hashes.

  Transaction data is included for each block.
  """
  def fetch_blocks_by_hash(block_hashes) do
    batched_requests =
      for block_hash <- block_hashes do
        %{
          "id" => block_hash,
          "jsonrpc" => "2.0",
          "method" => "eth_getBlockByHash",
          "params" => [block_hash, true]
        }
      end

    batched_requests
    |> json_rpc(config(:url))
    |> handle_get_block_by_number()
    |> case do
      {:ok, _next, results} -> {:ok, results}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches blocks by block number range.
  """
  def fetch_blocks_by_range(block_start, block_end) do
    block_start
    |> build_batch_get_block_by_number(block_end)
    |> json_rpc(config(:url))
    |> handle_get_block_by_number()
  end

  @doc """
  Fetches internal transactions from client-specific API.
  """
  def fetch_internal_transactions(hashes) when is_list(hashes) do
    Parity.fetch_internal_transactions(hashes)
  end

  def fetch_transaction_receipts(hashes) when is_list(hashes) do
    Receipts.fetch(hashes)
  end

  @doc """
  1. POSTs JSON `payload` to `url`
  2. Decodes the response
  3. Handles the response

  ## Returns

  * Handled response
  * `{:error, reason}` if POST failes
  """
  def json_rpc(payload, url) do
    json = encode_json(payload)
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, json, headers, config(:http)) do
      {:ok, %HTTPoison.Response{body: body, status_code: code}} ->
        body |> decode_json(payload, url) |> handle_response(code)

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a filter subscription that can be polled for retreiving new blocks.
  """
  def listen_for_new_blocks do
    id = DateTime.utc_now() |> DateTime.to_unix()

    request = %{
      "id" => id,
      "jsonrpc" => "2.0",
      "method" => "eth_newBlockFilter",
      "params" => []
    }

    json_rpc(request, config(:url))
  end

  @doc """
  Converts `t:nonce/0` to `t:non_neg_integer/0`
  """
  def nonce_to_integer(nonce) do
    hexadecimal_to_integer(nonce)
  end

  @doc """
  Converts `t:quantity/0` to `t:non_neg_integer/0`.
  """
  def quantity_to_integer(quantity) do
    hexadecimal_to_integer(quantity)
  end

  @doc """
  Converts `t:timestamp/0` to `t:DateTime.t/0`
  """
  def timestamp_to_datetime(timestamp) do
    timestamp
    |> hexadecimal_to_integer()
    |> Timex.from_unix()
  end

  defp build_batch_get_block_by_number(block_start, block_end) do
    for current <- block_start..block_end do
      %{
        "id" => current,
        "jsonrpc" => "2.0",
        "method" => "eth_getBlockByNumber",
        "params" => [int_to_hash_string(current), true]
      }
    end
  end

  defp encode_json(data), do: Jason.encode_to_iodata!(data)

  defp decode_json(body, posted_payload, url) do
    Jason.decode!(body)
  rescue
    Jason.DecodeError ->
      Logger.error("""
      failed to decode json payload:

          url: #{inspect(url)}

          body: #{inspect(body)}

          posted payload: #{inspect(posted_payload)}

      """)

      raise("bad jason")
  end

  defp handle_get_block_by_number({:ok, results}) do
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

  defp handle_get_block_by_number({:error, reason}) do
    {:error, reason}
  end

  defp handle_response(resp, 200) do
    case resp do
      [%{} | _] = batch_resp -> {:ok, batch_resp}
      %{"error" => error} -> {:error, error}
      %{"result" => result} -> {:ok, result}
    end
  end

  defp handle_response(resp, _status) do
    {:error, resp}
  end

  defp hexadecimal_to_integer("0x" <> hexadecimal_digits) do
    String.to_integer(hexadecimal_digits, 16)
  end

  defp int_to_hash_string(number), do: "0x" <> Integer.to_string(number, 16)
end
