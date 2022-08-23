defmodule Indexer.Fetcher.InternalTransaction do
  @moduledoc """
  Fetches and indexes `t:Explorer.Chain.InternalTransaction.t/0`.
  See `async_fetch/1` for details on configuring limits.
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  import Indexer.Block.Fetcher, only: [async_import_coin_balances: 2]

  alias Explorer.Celo.{InternalTransactionCache, Util}
  alias Explorer.Chain
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Cache.{Accounts, Blocks}
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.TokenBalance
  alias Indexer.Transform.{Addresses, TokenTransfers}

  @behaviour BufferedTask

  @max_batch_size 3
  @max_concurrency 55
  @defaults [
    flush_interval: :timer.seconds(3),
    poll_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    dedup_entries: true,
    poll: true,
    task_supervisor: Indexer.Fetcher.InternalTransaction.TaskSupervisor,
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
  @spec async_fetch([Block.block_number()]) :: :ok
  def async_fetch(block_numbers, timeout \\ 5000) when is_list(block_numbers) do
    BufferedTask.buffer(__MODULE__, block_numbers, timeout)
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
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      Chain.stream_blocks_with_unfetched_internal_transactions(initial, fn block_number, acc ->
        reducer.(block_number, acc)
      end)

    final
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.InternalTransaction.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(block_numbers, json_rpc_named_arguments) do
    unique_numbers = Enum.uniq(block_numbers)

    unique_numbers_count = Enum.count(unique_numbers)
    Logger.metadata(count: unique_numbers_count)

    Logger.debug("fetching internal transactions for blocks")

    json_rpc_named_arguments
    |> Keyword.fetch!(:variant)
    |> case do
      EthereumJSONRPC.Parity ->
        EthereumJSONRPC.fetch_block_internal_transactions(unique_numbers, json_rpc_named_arguments)

      EthereumJSONRPC.Besu ->
        EthereumJSONRPC.fetch_block_internal_transactions(unique_numbers, json_rpc_named_arguments)

      _jsonrpc_variant ->
        try do
          fetch_block_internal_transactions_by_transactions(unique_numbers, json_rpc_named_arguments)
        rescue
          error ->
            {:error, error}
        end
    end
    |> case do
      {:ok, internal_transactions_params} ->
        import_internal_transaction(internal_transactions_params, unique_numbers)

      {:error, reason} ->
        block_numbers = unique_numbers |> inspect(charlists: :as_lists)

        Logger.error(
          "failed to fetch internal transactions for #{unique_numbers_count} blocks: #{block_numbers} reason: #{inspect(reason)}",
          error_count: unique_numbers_count
        )

        :ok

      :ignore ->
        :ok
    end
  end

  def import_first_trace(internal_transactions_params) do
    imports =
      Chain.import(%{
        internal_transactions: %{params: internal_transactions_params, with: :blockless_changeset},
        timeout: :infinity
      })

    case imports do
      {:error, step, reason, _changes_so_far} ->
        Logger.error(
          fn ->
            [
              "failed to import first trace for tx: ",
              inspect(reason)
            ]
          end,
          step: step
        )
    end
  end

  defp fetch_block_internal_transactions_by_transactions(unique_numbers, json_rpc_named_arguments) do
    Enum.reduce(unique_numbers, {:ok, []}, fn
      block_number, {:ok, acc_list} ->
        {:ok, block} = Chain.number_to_any_block(block_number)

        cached = InternalTransactionCache.get(block_number)

        if cached do
          {:ok, cached}
        else
          block_number
          |> Chain.get_transactions_of_block_number()
          |> extract_transaction_parameters()
          |> perform_internal_transaction_fetch(block, json_rpc_named_arguments)
          |> handle_transaction_fetch_results(block_number, acc_list)
        end

      _, error_or_ignore ->
        error_or_ignore
    end)
  end

  defp extract_transaction_parameters(transactions) do
    transactions
    |> Enum.map(&params(&1))
  end

  # Transforms parameters from Transaction struct to those expected by EthereumJSONRPC.fetch_internal_transactions
  defp params(%Transaction{block_number: block_number, hash: hash, index: index, block_hash: block_hash})
       when is_integer(block_number) do
    %{block_number: block_number, hash_data: to_string(hash), transaction_index: index, block_hash: block_hash}
  end

  defp perform_internal_transaction_fetch([], block, _jsonrpc_named_arguments), do: {{:ok, []}, 0, block}

  defp perform_internal_transaction_fetch(transactions, block, jsonrpc_named_arguments) do
    case EthereumJSONRPC.fetch_internal_transactions(transactions, jsonrpc_named_arguments) do
      {:ok, res} ->
        {{:ok, res}, Enum.count(transactions), block}

      {:error, reason} ->
        {:error, reason, block}
    end
  end

  defp handle_transaction_fetch_results(
         {{:ok, internal_transactions}, tx_count, %Block{gas_used: used_gas, hash: block_hash}},
         block_number,
         acc
       ) do
    Logger.debug(
      "Found #{Enum.count(internal_transactions)} internal tx for block #{block_number} had txs: #{tx_count} used gas #{used_gas}"
    )

    case check_db(tx_count, used_gas) do
      {:ok} ->
        {:ok, add_block_hash(block_hash, internal_transactions) ++ acc}

      {:error, :block_not_indexed_properly} ->
        Logger.error(
          "Block #{block_number} not indexed properly: tx_count=#{tx_count} used_gas=#{used_gas}, itx fetch will be retried"
        )

        InternalTransactionCache.store(block_number, add_block_hash(block_hash, internal_transactions))

        {:ok, acc}
    end
  end

  defp handle_transaction_fetch_results({:error, e, _block}, block_number, acc) do
    Logger.error("Failed to fetch internal transactions for block #{block_number} : error=#{inspect(e)}")

    {:ok, acc}
  end

  defp check_db(0, _used_gas), do: {:error, :block_not_indexed_properly}
  defp check_db(_tx_count, %Decimal{coef: 0}), do: {:error, :block_not_indexed_properly}
  defp check_db(_tx_count, _used_gas), do: {:ok}

  # block_hash is required for TokenTransfers.parse_itx
  defp add_block_hash(block_hash, internal_transactions) do
    Enum.map(internal_transactions, fn a -> Map.put(a, :block_hash, block_hash) end)
  end

  defp decode("0x" <> str) do
    %{bytes: Base.decode16!(str, case: :mixed)}
  end

  defp add_gold_token_balances(gold_token, addresses, acc) do
    Enum.reduce(addresses, acc, fn
      %{fetched_coin_balance_block_number: bn, hash: hash}, acc ->
        MapSet.put(acc, %{
          address_hash: decode(hash),
          token_contract_address_hash: decode(gold_token),
          block_number: bn,
          token_type: "ERC-20",
          token_id: nil
        })

      _, acc ->
        acc
    end)
  end

  defp import_internal_transaction(internal_transactions_params, unique_numbers) do
    internal_transactions_params_without_failed_creations = remove_failed_creations(internal_transactions_params)

    addresses_params =
      Addresses.extract_addresses(%{
        internal_transactions: internal_transactions_params_without_failed_creations
      })

    # Gold token special updates
    token_transfers =
      with true <- Application.get_env(:indexer, Indexer.Block.Fetcher, [])[:enable_gold_token],
           {:ok, gold_token} <- Util.get_address("GoldToken") do
        set = add_gold_token_balances(gold_token, addresses_params, MapSet.new())
        TokenBalance.async_fetch(MapSet.to_list(set))

        %{token_transfers: celo_token_transfers} =
          TokenTransfers.parse_itx(internal_transactions_params_without_failed_creations, gold_token)

        celo_token_transfers
      else
        _ -> []
      end

    token_transfers_addresses_params =
      Addresses.extract_addresses(%{
        token_transfers: token_transfers
      })

    address_hash_to_block_number =
      Enum.into(token_transfers_addresses_params, %{}, fn %{fetched_coin_balance_block_number: block_number, hash: hash} ->
        {hash, block_number}
      end)

    empty_block_numbers =
      unique_numbers
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(internal_transactions_params_without_failed_creations, & &1.block_number))
      |> Enum.map(&%{block_number: &1})

    internal_transactions_and_empty_block_numbers =
      internal_transactions_params_without_failed_creations ++ empty_block_numbers

    imports =
      Chain.import(%{
        token_transfers: %{params: token_transfers},
        addresses: %{params: addresses_params},
        internal_transactions: %{params: internal_transactions_and_empty_block_numbers, with: :blockless_changeset},
        timeout: :infinity
      })

    case imports do
      {:ok, imported} ->
        Accounts.drop(imported[:addresses])
        Blocks.drop_nonconsensus(imported[:remove_consensus_of_missing_transactions_blocks])

        async_import_coin_balances(token_transfers_addresses_params, %{
          address_hash_to_fetched_balance_block_number: address_hash_to_block_number
        })

      {:error, step, reason, _changes_so_far} ->
        Logger.error(
          fn ->
            [
              "failed to import internal transactions for blocks: ",
              inspect(reason)
            ]
          end,
          step: step,
          error_count: Enum.count(unique_numbers)
        )

        # re-queue the de-duped entries
        {:retry, unique_numbers}
    end
  end

  defp remove_failed_creations(internal_transactions_params) do
    internal_transactions_params
    |> Enum.map(fn internal_transaction_param ->
      transaction_index = internal_transaction_param[:transaction_index]
      block_number = internal_transaction_param[:block_number]

      failed_parent =
        internal_transactions_params
        |> Enum.filter(fn internal_transactions_param ->
          internal_transactions_param[:block_number] == block_number &&
            internal_transactions_param[:transaction_index] == transaction_index &&
            internal_transactions_param[:trace_address] == [] && !is_nil(internal_transactions_param[:error])
        end)
        |> Enum.at(0)

      if failed_parent do
        internal_transaction_param
        |> Map.delete(:created_contract_address_hash)
        |> Map.delete(:created_contract_code)
        |> Map.delete(:gas_used)
        |> Map.delete(:output)
        |> Map.put(:error, failed_parent[:error])
      else
        internal_transaction_param
      end
    end)
  end
end
