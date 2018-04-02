defmodule Explorer.ETH do
  @moduledoc """
  Ethereum JSONRPC client.

  ## Configuration

  Configuration for parity URLs can be provided with the
  following mix config:

      config :explorer, :eth_client,
        url: "https://sokol.poa.network",
        trace_url: "https://sokol-trace.poa.network",
        http: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :eth]]

  Note: the tracing node URL is provided separately from `:url`, via
  `:trace_url`. The trace URL and is used for `fetch_internal_transactions`,
  which is only a supported method on tracing nodes. The `:http` option is
  passed directly to the HTTP library (`HTTPoison`), which forwards the
  options down to `:hackney`.
  """
  require Logger

  def child_spec(_opts) do
    :hackney_pool.child_spec(:eth, recv_timeout: 60_000, timeout: 60_000, max_connections: 1000)
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

    json_rpc(batched_requests, config(:url))
  end

  def decode_int(hex) do
    {"0x", base_16} = String.split_at(hex, 2)
    String.to_integer(base_16, 16)
  end

  def decode_time(field) do
    field |> decode_int() |> Timex.from_unix()
  end

  def fetch_transaction_receipts(hashes) when is_list(hashes) do
    hashes
    |> Enum.map(fn hash ->
      %{
        "id" => hash,
        "jsonrpc" => "2.0",
        "method" => "eth_getTransactionReceipt",
        "params" => [hash]
      }
    end)
    |> json_rpc(config(:url))
    |> handle_receipts()
  end

  defp handle_receipts({:ok, results}) do
    results_map =
      Enum.into(results, %{}, fn %{"id" => hash, "result" => receipt} ->
        {hash,
         Map.merge(receipt, %{
           "transactionHash" => String.downcase(receipt["transactionHash"]),
           "transactionIndex" => decode_int(receipt["transactionIndex"]),
           "cumulativeGasUsed" => decode_int(receipt["cumulativeGasUsed"]),
           "gasUsed" => decode_int(receipt["gasUsed"]),
           "status" => decode_int(receipt["status"]),
           "logs" =>
             Enum.map(receipt["logs"], fn log ->
               Map.merge(log, %{"logIndex" => decode_int(log["logIndex"])})
             end)
         })}
      end)

    {:ok, results_map}
  end

  defp handle_receipts({:error, reason}) do
    {:error, reason}
  end

  def fetch_internal_transactions(hashes) when is_list(hashes) do
    hashes
    |> Enum.map(fn hash ->
      %{
        "id" => hash,
        "jsonrpc" => "2.0",
        "method" => "trace_replayTransaction",
        "params" => [hash, ["trace"]]
      }
    end)
    |> json_rpc(config(:trace_url))
    |> handle_internal_transactions()
  end

  defp handle_internal_transactions({:ok, results}) do
    results_map =
      Enum.into(results, %{}, fn
        %{"error" => error} ->
          throw({:error, error})

        %{"id" => hash, "result" => %{"trace" => traces}} ->
          {hash, Enum.map(traces, &decode_trace(&1))}
      end)

    {:ok, results_map}
  catch
    {:error, reason} -> {:error, reason}
  end

  defp handle_internal_transactions({:error, reason}) do
    {:error, reason}
  end

  defp decode_trace(%{"action" => action} = trace) do
    trace
    |> Map.merge(%{
      "action" =>
        Map.merge(action, %{
          "value" => decode_int(action["value"]),
          "gas" => decode_int(action["gas"])
        })
    })
    |> put_gas_used()
  end

  defp put_gas_used(%{"error" => _} = trace), do: trace

  defp put_gas_used(%{"result" => %{"gasUsed" => gas}} = trace) do
    put_in(trace, ["result", "gasUsed"], decode_int(gas))
  end

  @doc """
  Fetches blocks by block number range.
  """
  def fetch_blocks_by_range(block_start, block_end) do
    block_start
    |> build_batch_get_block_by_number(block_end)
    |> json_rpc(config(:url))
    |> handle_get_block_by_number(block_start, block_end)
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

  defp handle_get_block_by_number({:ok, results}, block_start, block_end) do
    {blocks, next} =
      Enum.reduce(results, {[], :more}, fn
        %{"result" => nil}, {blocks, _} -> {blocks, :end_of_chain}
        %{"result" => %{} = block}, {blocks, next} -> {[block | blocks], next}
      end)

    {:ok, next, decode_blocks(blocks), {block_start, block_end}}
  end

  defp handle_get_block_by_number({:error, reason}, block_start, block_end) do
    {:error, reason, {block_start, block_end}}
  end

  defp decode_blocks(blocks) do
    Enum.map(blocks, fn block ->
      Map.merge(block, %{
        "hash" => String.downcase(block["hash"]),
        "number" => decode_int(block["number"]),
        "gasUsed" => decode_int(block["gasUsed"]),
        "timestamp" => decode_time(block["timestamp"]),
        "difficulty" => decode_int(block["difficulty"]),
        "totalDifficulty" => decode_int(block["totalDifficulty"]),
        "size" => decode_int(block["size"]),
        "gasLimit" => decode_int(block["gasLimit"]),
        "transactions" => decode_transactions(block["transactions"])
      })
    end)
  end

  defp decode_transactions(transactions) do
    Enum.map(transactions, fn transaction ->
      Map.merge(transaction, %{
        "hash" => String.downcase(transaction["hash"]),
        "value" => decode_int(transaction["value"]),
        "gas" => decode_int(transaction["gas"]),
        "gasPrice" => decode_int(transaction["gasPrice"]),
        "nonce" => decode_int(transaction["nonce"])
      })
    end)
  end

  defp json_rpc(payload, url) do
    json = encode_json(payload)
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, json, headers, config(:http)) do
      {:ok, %HTTPoison.Response{body: body, status_code: code}} ->
        body |> decode_json(payload) |> handle_response(code)

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
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

  defp config(key) do
    :explorer
    |> Application.fetch_env!(:eth_client)
    |> Keyword.fetch!(key)
  end

  defp encode_json(data), do: Jason.encode_to_iodata!(data)

  defp decode_json(body, posted_payload) do
    Jason.decode!(body)
  rescue
    Jason.DecodeError ->
      Logger.error("""
      failed to decode json payload:

          #{inspect(body)}

          #{inspect(posted_payload)}

      """)

      raise("bad jason")
  end

  defp int_to_hash_string(number), do: "0x" <> Integer.to_string(number, 16)
end
