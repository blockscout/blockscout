defmodule Indexer.Fetcher.CosmosHash do
  @moduledoc """
  Fetches and indexes `t:Explorer.Chain.CosmosHash.t/0`.

  See `async_fetch/1` for details on configuring limits.
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias HTTPoison.{Error, Response}
  alias Explorer.Chain
  alias Explorer.Chain.{Transaction}
  alias Indexer.{BufferedTask, Tracer}

  @behaviour BufferedTask

  @max_batch_size System.get_env("MAX_BATCH_SIZE_COSMOS_HASH") || 10
  @max_concurrency System.get_env("MAX_CONCURRENCY_COSMOS_HASH") || 2
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    poll: true,
    task_supervisor: Indexer.Fetcher.CosmosHash.TaskSupervisor,
    metadata: [fetcher: :cosmos_hash]
  ]

  @doc """
  Asynchronously fetches cosmos hashes.
  """
  @spec async_fetch([Block.block_number()]) :: :ok
  def async_fetch(block_numbers, timeout \\ 5000) when is_list(block_numbers) do
    BufferedTask.buffer(__MODULE__, block_numbers, timeout)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      @defaults
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, {})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_block_numbers_with_unfetched_cosmos_hashes(initial, fn block_number, acc ->
          reducer.(block_number, acc)
      end)
    final
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.CosmosHash.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(block_numbers, _) do
    unique_numbers = Enum.uniq(block_numbers)
    Logger.debug("fetching cosmos hashes for transactions")
    Enum.each(unique_numbers, &fetch_and_import_cosmos_hash/1)
  end

  def get_cosmos_hash_params_by_range(range) do
    block_numbers = Enum.map(range, fn(number) -> number end)
    for block_number <- block_numbers do
      %{block_number => get_cosmos_hash_tx_list_mapping(block_number)}
    end
  end

  def put(transactions_without_cosmos_hashes, cosmos_hash_params) when is_list(transactions_without_cosmos_hashes)
                                                                  when is_list(cosmos_hash_params) do
    Enum.map(transactions_without_cosmos_hashes, fn transaction_params ->
      block_number = transaction_params[:block_number]
      cosmos_hash_params = Enum.find(cosmos_hash_params, fn param ->
        param[block_number] != nil
      end) |> Enum.at(0)
      tx_hash = transaction_params[:hash]
      params = elem(cosmos_hash_params, 1)

      param_cosmos = Enum.find(params, fn param ->
        param[:hash] == tx_hash
      end)

      if param_cosmos != nil do
        Map.put_new(transaction_params, :cosmos_hash, param_cosmos[:cosmos_hash])
      else
        Map.put_new(transaction_params, :cosmos_hash, nil)
      end
    end)
  end

  defp get_cosmos_hash_tx_list_mapping(block_number) do
    case http_request(block_info_url() <> Integer.to_string(block_number)) do
      {:error, reason} ->
        Logger.error("failed to fetch block info via api node: ", inspect(reason))
        nil
      {:ok, result} ->
        case result["block"]["data"]["txs"] do
          nil ->
            Logger.debug("block_number: #{block_number} does not have any transactions")
            nil
          [] ->
            Logger.debug("block_number: #{block_number} does not have any transactions")
            nil
          [_|_] ->
            # realtime fetcher handle maximum 20 txs/block
            cosmos_hashes = for tx <- result["block"]["data"]["txs"] |> Enum.slice(0, 20) do
              raw_txn_to_cosmos_hash(tx)
            end
            for cosmos_hash <- cosmos_hashes do
              case http_request(txn_info_url() <> cosmos_hash) do
                {:error, reason} ->
                  Logger.error("failed to fetch txn info via api node: ", inspect(reason))
                  nil
                {:ok, result} ->
                  tx_message = Enum.at(result["tx"]["body"]["messages"], 0)
                  %{hash: tx_message["hash"], cosmos_hash: cosmos_hash}
              end
            end
        end
    end
  end

  defp fetch_and_import_cosmos_hash(block_number) do
    case http_request(block_info_url() <> Integer.to_string(block_number)) do
      {:error, reason} ->
        Logger.error("failed to fetch block info via api node: ", inspect(reason))
      {:ok, result} ->
        case result["block"]["data"]["txs"] do
          nil -> Logger.debug("block_number: #{block_number} does not have any transactions")
          [] -> Logger.debug("block_number: #{block_number} does not have any transactions")
          [_|_] ->
            tx_hashes = Chain.get_tx_hashes_of_block_number_with_unfetched_cosmos_hashes(block_number)
                        |> Enum.map(fn tx -> Chain.Hash.to_string(tx) end)

            for cosmos_raw_tx <- result["block"]["data"]["txs"] do
              cosmos_hash = raw_txn_to_cosmos_hash(cosmos_raw_tx)
              case http_request(txn_info_url() <> cosmos_hash) do
                {:error, reason} ->
                  Logger.error("failed to fetch txn info via api node: ", inspect(reason))
                {:ok, result} ->
                  tx_messages = result["tx"]["body"]["messages"]
                  #TODO: need improve using update by batch
                  for %{"hash" => hash, "@type" => type} when type == "/ethermint.evm.v1.MsgEthereumTx"
                      <- tx_messages do
                    if Enum.member?(tx_hashes, hash) do
                      Transaction.update_cosmos_hash(hash, cosmos_hash)
                    end
                  end
              end
            end
        end
    end
  end

  @spec base_api_url :: String.t()
  defp base_api_url() do
    System.get_env("API_NODE_URL")
  end

  @spec block_info_url :: String.t()
  defp block_info_url() do
    base_api_url() <> "/cosmos/base/tendermint/v1beta1/blocks/"
  end

  @spec txn_info_url :: String.t()
  defp txn_info_url() do
    base_api_url() <> "/cosmos/tx/v1beta1/txs/"
  end

  defp raw_txn_to_cosmos_hash(raw_txn) do
    Base.encode16(:crypto.hash(:sha256, elem(Base.decode64(raw_txn), 1)))
  end

  defp headers do
    [{"Content-Type", "application/json"}]
  end

  defp decode_json(data) do
    Jason.decode!(data)
  rescue
    _ -> data
  end

  defp parse_http_success_response(body) do
    body_json = decode_json(body)

    cond do
      is_map(body_json) ->
        {:ok, body_json}

      is_list(body_json) ->
        {:ok, body_json}

      true ->
        {:ok, body}
    end
  end

  defp parse_http_error_response(body) do
    body_json = decode_json(body)

    if is_map(body_json) do
      {:error, body_json["error"]}
    else
      {:error, body}
    end
  end

  defp http_request(source_url) do
    case HTTPoison.get(source_url, headers()) do
      {:ok, %Response{body: body, status_code: 200}} ->
        parse_http_success_response(body)

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..526 ->
        parse_http_error_response(body)

      {:ok, %Response{status_code: status_code}} when status_code in 300..308 ->
        {:error, "Source redirected"}

      {:ok, %Response{status_code: _status_code}} ->
        {:error, "Source unexpected status code"}

      {:error, %Error{reason: reason}} ->
        {:error, reason}

      {:error, :nxdomain} ->
        {:error, "Source is not responsive"}

      {:error, _} ->
        {:error, "Source unknown response"}
    end
  end

end
