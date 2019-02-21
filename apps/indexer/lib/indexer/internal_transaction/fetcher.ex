defmodule Indexer.InternalTransaction.Fetcher do
  @moduledoc """
  Fetches and indexes `t:Explorer.Chain.InternalTransaction.t/0`.

  See `async_fetch/1` for details on configuring limits.
  """

  use Spandex.Decorators

  require Logger

  import Indexer.Block.Fetcher, only: [async_import_coin_balances: 2]

  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash}
  alias Indexer.{AddressExtraction, BufferedTask, Tracer}

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.InternalTransaction.TaskSupervisor,
    metadata: [fetcher: :internal_transaction]
  ]

  @doc """
  Asynchronously fetches internal transactions.

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
  @spec async_fetch([%{required(:block_number) => Block.block_number(), required(:hash) => Hash.Full.t()}]) :: :ok
  def async_fetch(transactions_fields, timeout \\ 5000) when is_list(transactions_fields) do
    entries = Enum.map(transactions_fields, &entry/1)

    BufferedTask.buffer(__MODULE__, entries, timeout)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_transactions_with_unfetched_internal_transactions(
        [:block_number, :hash, :index],
        initial,
        fn transaction_fields, acc ->
          transaction_fields
          |> entry()
          |> reducer.(acc)
        end
      )

    final
  end

  defp entry(%{block_number: block_number, hash: %Hash{bytes: bytes}, index: index}) when is_integer(block_number) do
    {block_number, bytes, index}
  end

  defp params({block_number, hash_bytes, index}) when is_integer(block_number) do
    {:ok, hash} = Hash.Full.cast(hash_bytes)
    %{block_number: block_number, hash_data: to_string(hash), transaction_index: index}
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.InternalTransaction.Fetcher.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(entries, json_rpc_named_arguments) do
    unique_entries = unique_entries(entries)

    unique_entries_count = Enum.count(unique_entries)
    Logger.metadata(count: unique_entries_count)

    Logger.debug("fetching internal transactions for transactions")

    unique_entries
    |> Enum.map(&params/1)
    |> EthereumJSONRPC.fetch_internal_transactions(json_rpc_named_arguments)
    |> case do
      {:ok, internal_transactions_params} ->
        internal_transactions_params_without_failed_creations = remove_failed_creations(internal_transactions_params)

        addresses_params =
          AddressExtraction.extract_addresses(%{
            internal_transactions: internal_transactions_params_without_failed_creations
          })

        address_hash_to_block_number =
          Enum.into(addresses_params, %{}, fn %{fetched_coin_balance_block_number: block_number, hash: hash} ->
            {hash, block_number}
          end)

        with {:ok, imported} <-
               Chain.import(%{
                 addresses: %{params: addresses_params},
                 internal_transactions: %{params: internal_transactions_params_without_failed_creations},
                 timeout: :infinity
               }) do
          async_import_coin_balances(imported, %{
            address_hash_to_fetched_balance_block_number: address_hash_to_block_number
          })
        else
          {:error, step, reason, _changes_so_far} ->
            Logger.error(
              fn ->
                [
                  "failed to import internal transactions for transactions: ",
                  inspect(reason)
                ]
              end,
              step: step,
              error_count: unique_entries_count
            )

            # re-queue the de-duped entries
            {:retry, unique_entries}
        end

      {:error, reason} ->
        Logger.error(fn -> ["failed to fetch internal transactions for transactions: ", inspect(reason)] end,
          error_count: unique_entries_count
        )

        # re-queue the de-duped entries
        {:retry, unique_entries}

      :ignore ->
        :ok
    end
  end

  # Protection and improved reporting for https://github.com/poanetwork/blockscout/issues/289
  defp unique_entries(entries) do
    entries_by_hash_bytes = Enum.group_by(entries, &elem(&1, 1))

    if map_size(entries_by_hash_bytes) < length(entries) do
      {unique_entries, duplicate_entries} =
        entries_by_hash_bytes
        |> Map.values()
        |> uniques_and_duplicates()

      Logger.error(fn ->
        duplicate_entries
        |> Stream.with_index()
        |> Enum.reduce(
          ["Duplicate entries being used to fetch internal transactions:\n"],
          fn {entry, index}, acc ->
            [acc, "  ", to_string(index + 1), ". ", inspect(entry), "\n"]
          end
        )
      end)

      unique_entries
    else
      entries
    end
  end

  defp uniques_and_duplicates(groups) do
    Enum.reduce(groups, {[], []}, fn group, {acc_uniques, acc_duplicates} ->
      case group do
        [unique] ->
          {[unique | acc_uniques], acc_duplicates}

        [unique | _] = duplicates ->
          {[unique | acc_uniques], duplicates ++ acc_duplicates}
      end
    end)
  end

  defp remove_failed_creations(internal_transactions_params) do
    internal_transactions_params
    |> Enum.map(fn internal_transaction_params ->
      internal_transaction_params[:trace_address]

      failed_parent_index =
        Enum.find(internal_transaction_params[:trace_address], fn trace_address ->
          parent = Enum.at(internal_transactions_params, trace_address)

          !is_nil(parent[:error])
        end)

      failed_parent = failed_parent_index && Enum.at(internal_transactions_params, failed_parent_index)

      if failed_parent do
        internal_transaction_params
        |> Map.delete(:created_contract_address_hash)
        |> Map.delete(:created_contract_code)
        |> Map.delete(:gas_used)
        |> Map.delete(:output)
        |> Map.put(:error, failed_parent[:error])
      else
        internal_transaction_params
      end
    end)
  end
end
