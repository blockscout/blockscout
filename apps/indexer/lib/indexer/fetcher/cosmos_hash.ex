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
  @max_concurrency 4
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

  ## Limiting Upstream Load

  Internal transactions are an expensive upstream operation. The number of
  results to fetch is configured by `@max_batch_size` and represents the number
  of transaction hashes to request internal transactions in a single JSONRPC
  request. Defaults to `#{@max_batch_size}`.

  The `@max_concurrency` attribute configures the  number of concurrent requests
  of `@max_batch_size` to allow against the JSONRPC. Defaults to `#{@max_concurrency}`.

  *Note*: The internal transactions for individual transactions cannot be paginated,
  so the total number of internal transactions that could be produced is unknown.
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
      Chain.stream_transactions_with_unfetched_cosmos_hashes(initial, fn block_number, acc ->
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
    Logger.info("TRUNG")
    Enum.each(unique_numbers, fn(block_number) ->
      Logger.info(block_number)
    end)
    Logger.debug("fetching cosmos hashes for transactions")

  end

  defp base_url() do
    "https://api.astranaut.dev/cosmos/base/tendermint/v1beta1/blocks/"
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
