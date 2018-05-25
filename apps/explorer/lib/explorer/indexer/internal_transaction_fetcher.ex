defmodule Explorer.Indexer.InternalTransactionFetcher do
  @moduledoc """
  Fetches and indexes `t:Explorer.Chain.InternalTransaction.t/0`.

  See `async_fetch/1` for details on configuring limits.
  """

  alias Explorer.{BufferedTask, Chain, Indexer}
  alias Explorer.Indexer.BlockFetcher.AddressExtraction
  alias Explorer.Indexer.AddressBalanceFetcher
  alias Explorer.Chain.{Hash, Transaction}

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    stream_chunk_size: 5000
  ]

  @doc """
  Asynchronously fetches internal transactions from list of `t:Explorer.Chain.Hash.t/0`.

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
  def async_fetch(transaction_hashes) do
    string_hashes = for hash <- transaction_hashes, do: Hash.to_string(hash)

    BufferedTask.buffer(__MODULE__, string_hashes)
  end

  @doc false
  def child_spec(provided_opts) do
    opts = Keyword.merge(@defaults, provided_opts)
    Supervisor.child_spec({BufferedTask, {__MODULE__, opts}}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(acc, reducer) do
    Chain.stream_transactions_with_unfetched_internal_transactions([:hash], acc, fn %Transaction{hash: hash}, acc ->
      reducer.(Hash.to_string(hash), acc)
    end)
  end

  @impl BufferedTask
  def run(transaction_hashes, _retries) do
    Indexer.debug(fn -> "fetching internal transactions for #{length(transaction_hashes)} transactions" end)

    case EthereumJSONRPC.fetch_internal_transactions(transaction_hashes) do
      {:ok, internal_transactions_params} ->
        addresses_params = AddressExtraction.extract_addresses(%{internal_transactions: internal_transactions_params})

        [
          addresses: [params: addresses_params],
          internal_transactions: [params: internal_transactions_params],
          transactions: [hashes: transaction_hashes]
        ]
        |> Chain.import_internal_transactions()
        |> fetch_new_balances()

      {:error, reason} ->
        Indexer.debug(fn ->
          "failed to fetch internal transactions for #{length(transaction_hashes)} transactions: #{inspect(reason)}"
        end)

        {:retry, reason}
    end
  end

  defp fetch_new_balances({:ok, %{addresses: address_hashes}}) do
    AddressBalanceFetcher.async_fetch_balances(address_hashes)
    :ok
  end

  defp fetch_new_balances({:error, failed_operation, reason, _changes}) do
    {:retry, {failed_operation, reason}}
  end
end
