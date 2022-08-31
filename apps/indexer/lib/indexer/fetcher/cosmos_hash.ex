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
  alias Indexer.{BufferedTask, Tracer}

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 2
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
    case unique_numbers do
      [nil] ->
        {:retry, block_numbers}
      [] ->
        {:retry, block_numbers}
      [_|_] ->
        Enum.each(unique_numbers, &fetch_and_import_cosmos_hash/1)
    end
  end

  def get_cosmos_hash_params_by_range(range) do
    case range do
      nil ->
        Logger.info("range is nil")
        nil
      _ ->
        block_numbers = Enum.map(range, fn(number) -> number end)
        for block_number <- block_numbers do
          %{block_number => get_cosmos_hash_tx_list_mapping(block_number)}
        end
    end
  end

  def put(transactions_without_cosmos_hashes, params) when is_list(transactions_without_cosmos_hashes) do
    case params do
      [_|_] ->
        Enum.map(transactions_without_cosmos_hashes, fn transaction_params ->
          block_number = transaction_params[:block_number]
          cosmos_hash_params = Enum.find(params, fn param ->
            is_nil(param[block_number]) == false
          end) |> Enum.at(0) |> elem(1)

          param_cosmos = Enum.find(cosmos_hash_params, fn param ->
            param[:hash] == transaction_params[:hash]
          end)

          if is_nil(param_cosmos) == false do
            Map.put_new(transaction_params, :cosmos_hash, param_cosmos[:cosmos_hash])
          else
            Map.put_new(transaction_params, :cosmos_hash, nil)
          end
        end)
      _ ->
        Enum.map(transactions_without_cosmos_hashes, fn transaction_params ->
          Map.put_new(transaction_params, :cosmos_hash, nil)
        end)
    end
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
            for tx <- result["block"]["data"]["txs"] do
              ethermint_hash = raw_txn_to_ethermint_hash(tx)
              cosmos_hash = raw_txn_to_cosmos_hash(tx)
              %{hash: ethermint_hash, cosmos_hash: cosmos_hash}
            end
        end
    end
  end

  defp fetch_and_import_cosmos_hash(block_number) when is_nil(block_number) == false do
    tx_hashes_string = Chain.get_tx_hashes_of_block_number_with_unfetched_cosmos_hashes(block_number)
                       |> Enum.map(fn tx -> Chain.Hash.to_string(tx) end)
    list_mapping = get_cosmos_hash_tx_list_mapping(block_number)

    params = for %{hash: hash, cosmos_hash: cosmos_hash} when is_nil(hash) == false <- list_mapping do
      if Enum.member?(tx_hashes_string, hash) do
        %{hash: hash, cosmos_hash: cosmos_hash}
      else
        nil
      end
    end |> Enum.filter(fn elem -> is_nil(elem) == false end)
    
    list_params = for %{hash: hash, cosmos_hash: cosmos_hash} <- params do
      {:ok, tx_hash} = Chain.string_to_transaction_hash(hash)
      %{hash: tx_hash, cosmos_hash: cosmos_hash}
    end
    Chain.update_transactions_cosmos_hashes_by_batch(list_params)
  end

  @spec base_api_url :: String.t()
  defp base_api_url() do
    System.get_env("API_NODE_URL")
  end

  @spec block_info_url :: String.t()
  defp block_info_url() do
    base_api_url() <> "/cosmos/base/tendermint/v1beta1/blocks/"
  end

  defp raw_txn_to_cosmos_hash(raw_txn) do
    Base.encode16(:crypto.hash(:sha256, elem(Base.decode64(raw_txn), 1)))
  end

  defp raw_binary_to_string(raw) do
    codepoints = String.codepoints(raw)
    Enum.reduce(codepoints,
      fn(w, result) ->
        cond do
          String.valid?(w) ->
            result <> w
          true ->
            << parsed :: 8>> = w
            result <>   << parsed :: utf8 >>
        end
      end)
  end

  defp raw_txn_to_ethermint_hash(raw_txn) do
    string = raw_binary_to_string(Base.decode64!(raw_txn))
    if String.contains?(string, "/ethermint.evm.v1.MsgEthereumTx") do
      Regex.scan(~r/0x[0-9a-f]{64}/, string) |> Enum.at(0) |> Enum.at(0)
    else
      nil
    end
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
