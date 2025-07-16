# credo:disable-for-this-file
defmodule Indexer.Fetcher.InternalTransaction do
  @moduledoc """
  Fetches and indexes `t:Explorer.Chain.InternalTransaction.t/0`.

  See `async_fetch/1` for details on configuring limits.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  import Indexer.Block.Fetcher,
    only: [
      async_import_coin_balances: 2,
      async_import_token_balances: 2,
      token_transfers_merge_token: 2
    ]

  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash, PendingBlockOperation, PendingTransactionOperation, Transaction}
  alias Explorer.Chain.Cache.{Accounts, Blocks}
  alias Explorer.Chain.Zilliqa.Helper, as: ZilliqaHelper
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.InternalTransaction.Supervisor, as: InternalTransactionSupervisor
  alias Indexer.Transform.Celo.TransactionTokenTransfers, as: CeloTransactionTokenTransfers
  alias Indexer.Transform.{AddressCoinBalances, Addresses, AddressTokenBalances}

  @behaviour BufferedTask

  @default_max_batch_size 10
  @default_max_concurrency 4

  @doc """
  Asynchronously fetches internal transactions.

  ## Limiting Upstream Load

  Internal transactions are an expensive upstream operation. The number of
  results to fetch is configured by `@max_batch_size` and represents the number
  of transaction hashes to request internal transactions in a single JSONRPC
  request. Defaults to `#{@default_max_batch_size}`.

  The `@max_concurrency` attribute configures the  number of concurrent requests
  of `@max_batch_size` to allow against the JSONRPC. Defaults to `#{@default_max_concurrency}`.

  *Note*: The internal transactions for individual transactions cannot be paginated,
  so the total number of internal transactions that could be produced is unknown.
  """
  @spec async_fetch([Block.block_number()], [Transaction.t()], boolean()) :: :ok
  def async_fetch(block_numbers, transactions, realtime?, timeout \\ 5000) when is_list(block_numbers) do
    if InternalTransactionSupervisor.disabled?() do
      :ok
    else
      data = data_for_buffer(block_numbers, transactions)
      BufferedTask.buffer(__MODULE__, data, realtime?, timeout)
    end
  end

  defp data_for_buffer(block_numbers, transactions) do
    json_rpc_named_arguments = Application.get_env(:indexer, :json_rpc_named_arguments)

    case queue_data_type(json_rpc_named_arguments) do
      :block_number -> block_numbers
      :transaction_params -> Enum.map(transactions, &Map.take(&1, [:block_number, :hash, :index]))
    end
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
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, json_rpc_named_arguments) do
    stream_reducer = RangesHelper.stream_reducer_traceable(reducer)

    {:ok, final} =
      case queue_data_type(json_rpc_named_arguments) do
        :block_number ->
          PendingBlockOperation.stream_blocks_with_unfetched_internal_transactions(initial, stream_reducer)

        :transaction_params ->
          PendingTransactionOperation.stream_transactions_with_unfetched_internal_transactions(initial, stream_reducer)
      end

    final
  end

  defp params(%{block_number: block_number, hash: hash, index: index}) when is_integer(block_number) do
    %{block_number: block_number, hash_data: to_string(hash), transaction_index: index}
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.InternalTransaction.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(block_numbers_or_transactions, json_rpc_named_arguments) do
    data_type = queue_data_type(json_rpc_named_arguments)
    filtered_data = filter_block_numbers(block_numbers_or_transactions, data_type, json_rpc_named_arguments)

    case fetch_internal_transactions(filtered_data, json_rpc_named_arguments, data_type) do
      {:ok, internal_transactions_params} ->
        safe_import_internal_transaction(internal_transactions_params, filtered_data, data_type)

      {:error, reason} ->
        Logger.error(
          fn ->
            [
              "failed to fetch internal transactions for #{data_type} #{inspect(filtered_data)}: ",
              Exception.format(:error, reason)
            ]
          end,
          error_count: Enum.count(filtered_data)
        )

        handle_not_found_transaction(reason)

        # re-queue the de-duped entries
        {:retry, filtered_data}

      {:error, reason, stacktrace} ->
        Logger.error(
          fn ->
            [
              "failed to fetch internal transactions for #{data_type} #{inspect(filtered_data)}: ",
              Exception.format(:error, reason, stacktrace)
            ]
          end,
          error_count: Enum.count(filtered_data)
        )

        handle_not_found_transaction(reason)

        # re-queue the de-duped entries
        {:retry, filtered_data}

      :ignore ->
        :ok
    end
  end

  defp fetch_internal_transactions(block_numbers_or_transactions, json_rpc_named_arguments, data_type) do
    Logger.metadata(count: Enum.count(block_numbers_or_transactions))

    case data_type do
      :block_number ->
        Logger.debug("fetching internal transactions by blocks")

        block_numbers_or_transactions
        |> check_and_filter_block_numbers()
        |> fetch_block_internal_transactions(json_rpc_named_arguments)

      :transaction_params ->
        Logger.debug("fetching internal transactions by transactions")

        try do
          block_numbers_or_transactions
          |> check_and_filter_transactions()
          |> fetch_internal_transactions_by_transactions(json_rpc_named_arguments)
        rescue
          error ->
            {:error, error, __STACKTRACE__}
        end
    end
  end

  # TODO: remove this function after the migration of internal transactions PK to [:block_hash, :transaction_index, :index]
  defp fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments) do
    variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

    if variant in block_traceable_variants() do
      EthereumJSONRPC.fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments)
    else
      Enum.reduce(block_numbers, {:ok, []}, fn
        block_number, {:ok, acc_list} ->
          block_number
          |> Chain.get_transactions_of_block_number()
          |> filter_non_traceable_transactions()
          |> Enum.map(&params/1)
          |> case do
            [] ->
              {:ok, []}

            transactions ->
              try do
                EthereumJSONRPC.fetch_internal_transactions(transactions, json_rpc_named_arguments)
              catch
                :exit, error ->
                  {:error, error, __STACKTRACE__}
              end
          end
          |> case do
            {:ok, internal_transactions} -> {:ok, internal_transactions ++ acc_list}
            error_or_ignore -> error_or_ignore
          end

        _, error_or_ignore ->
          error_or_ignore
      end)
    end
  end

  @default_block_traceable_variants [
    EthereumJSONRPC.Nethermind,
    EthereumJSONRPC.Erigon,
    EthereumJSONRPC.Besu,
    EthereumJSONRPC.RSK,
    EthereumJSONRPC.Filecoin
  ]
  defp block_traceable_variants do
    if Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)[:block_traceable?] do
      [EthereumJSONRPC.Geth | @default_block_traceable_variants]
    else
      @default_block_traceable_variants
    end
  end

  defp drop_genesis(block_numbers, json_rpc_named_arguments) do
    first_block = Application.get_env(:indexer, :trace_first_block)

    if first_block in block_numbers do
      case EthereumJSONRPC.fetch_blocks_by_numbers([first_block], json_rpc_named_arguments) do
        {:ok, %{transactions_params: [_ | _]}} -> block_numbers
        _ -> block_numbers -- [first_block]
      end
    else
      block_numbers
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
              "failed to import first trace for transaction: ",
              inspect(reason)
            ]
          end,
          step: step
        )
    end
  end

  defp filter_block_numbers(block_numbers, :block_number, json_rpc_named_arguments) do
    block_numbers
    |> Enum.uniq()
    |> Chain.filter_non_refetch_needed_block_numbers()
    |> RangesHelper.filter_traceable_block_numbers()
    |> drop_genesis(json_rpc_named_arguments)
  end

  defp filter_block_numbers(transactions_params, :transaction_params, _json_rpc_named_arguments),
    do: transactions_params

  defp check_and_filter_block_numbers(block_numbers) do
    Enum.reduce(block_numbers, [], fn number, acc ->
      if is_integer(number) do
        [number | acc]
      else
        Logger.error("InternalTransaction fetcher expected block number but got #{number}")
        acc
      end
    end)
  end

  defp check_and_filter_transactions(transactions) do
    Enum.reduce(transactions, [], fn transaction, acc ->
      case transaction do
        %{block_number: block_number, hash: _hash, index: _index} when is_integer(block_number) ->
          [transaction | acc]

        _ ->
          Logger.error("InternalTransaction fetcher expected transaction but got #{inspect(transaction)}")
          acc
      end
    end)
  end

  defp fetch_internal_transactions_by_transactions(transactions, json_rpc_named_arguments) do
    transactions
    |> filter_non_traceable_transactions()
    |> Enum.map(&params/1)
    |> case do
      [] ->
        {:ok, []}

      transactions ->
        try do
          EthereumJSONRPC.fetch_internal_transactions(transactions, json_rpc_named_arguments)
        catch
          :exit, error ->
            {:error, error, __STACKTRACE__}
        end
    end
  end

  # TODO: should we cover this with tests?
  @zetachain_non_traceable_type 88
  defp filter_non_traceable_transactions(transactions) do
    case Application.get_env(:explorer, :chain_type) do
      :zetachain -> Enum.reject(transactions, &(&1.type == @zetachain_non_traceable_type))
      :zilliqa -> Enum.reject(transactions, &ZilliqaHelper.scilla_transaction?/1)
      _ -> transactions
    end
  end

  defp safe_import_internal_transaction(internal_transactions_params, block_numbers, data_type) do
    import_internal_transaction(internal_transactions_params, block_numbers, data_type)
  rescue
    Postgrex.Error ->
      handle_foreign_key_violation(internal_transactions_params, block_numbers, data_type)
      {:retry, block_numbers}
  end

  defp import_internal_transaction(internal_transactions_params, transactions_params_or_unique_numbers, data_type) do
    internal_transactions_params_marked = mark_failed_transactions(internal_transactions_params)

    addresses_params =
      Addresses.extract_addresses(%{
        internal_transactions: internal_transactions_params_marked
      })

    address_hash_to_block_number =
      Enum.into(addresses_params, %{}, fn %{fetched_coin_balance_block_number: block_number, hash: hash} ->
        {String.downcase(hash), block_number}
      end)

    address_coin_balances_params_set =
      AddressCoinBalances.params_set(%{internal_transactions_params: internal_transactions_params_marked})

    empty_block_numbers =
      case data_type do
        :block_number ->
          transactions_params_or_unique_numbers
          |> MapSet.new()
          |> MapSet.difference(MapSet.new(internal_transactions_params_marked, & &1.block_number))
          |> Enum.map(&%{block_number: &1})

        :transaction_params ->
          []
      end

    internal_transactions_and_empty_block_numbers = internal_transactions_params_marked ++ empty_block_numbers

    celo_token_transfers_params =
      %{token_transfers: celo_token_transfers, tokens: celo_tokens} =
      if Application.get_env(:explorer, :chain_type) == :celo do
        block_number_to_block_hash =
          transactions_params_or_unique_numbers
          |> data_to_block_numbers(data_type)
          |> Chain.block_hash_by_number()
          |> Map.new(fn
            {block_number, block_hash} ->
              {block_number, Hash.to_string(block_hash)}
          end)

        CeloTransactionTokenTransfers.parse_internal_transactions(
          internal_transactions_params_marked,
          block_number_to_block_hash
        )
      else
        %{token_transfers: [], tokens: []}
      end

    imports =
      Chain.import(%{
        token_transfers: %{params: celo_token_transfers},
        tokens: %{params: celo_tokens},
        addresses: %{params: addresses_params},
        address_coin_balances: %{params: address_coin_balances_params_set},
        internal_transactions: %{params: internal_transactions_and_empty_block_numbers, with: :blockless_changeset},
        timeout: :infinity
      })

    case imports do
      {:ok, imported} ->
        Accounts.drop(imported[:addresses])
        Blocks.drop_nonconsensus(imported[:remove_consensus_of_missing_transactions_blocks])

        async_import_coin_balances(imported, %{
          address_hash_to_fetched_balance_block_number: address_hash_to_block_number
        })

        async_import_celo_token_balances(celo_token_transfers_params)

      {:error, step, reason, _changes_so_far} ->
        Logger.error(
          fn ->
            [
              "failed to import internal transactions for #{data_type}: ",
              inspect(reason)
            ]
          end,
          step: step,
          error_count: Enum.count(transactions_params_or_unique_numbers)
        )

        handle_unique_key_violation(reason, transactions_params_or_unique_numbers, data_type)

        # re-queue the de-duped entries
        {:retry, transactions_params_or_unique_numbers}
    end
  end

  defp mark_failed_transactions(internal_transactions_params) do
    # we store reversed trace addresses for more efficient list head-tail decomposition in has_failed_parent?
    failed_parent_paths =
      internal_transactions_params
      |> Enum.filter(& &1[:error])
      |> Enum.map(&Enum.reverse([&1.transaction_hash | &1.trace_address]))
      |> MapSet.new()

    internal_transactions_params
    |> Enum.map(fn internal_transaction_param ->
      if has_failed_parent?(
           failed_parent_paths,
           internal_transaction_param.trace_address,
           [internal_transaction_param.transaction_hash]
         ) do
        # TODO: consider keeping these deleted fields in the reverted transactions
        internal_transaction_param
        |> Map.delete(:created_contract_address_hash)
        |> Map.delete(:created_contract_code)
        |> Map.delete(:gas_used)
        |> Map.delete(:output)
        |> Map.put(:error, internal_transaction_param[:error] || "Parent reverted")
      else
        internal_transaction_param
      end
    end)
  end

  defp has_failed_parent?(failed_parent_paths, [head | tail], reverse_path_acc) do
    MapSet.member?(failed_parent_paths, reverse_path_acc) or
      has_failed_parent?(failed_parent_paths, tail, [head | reverse_path_acc])
  end

  # don't count itself as a parent
  defp has_failed_parent?(_failed_parent_paths, [], _reverse_path_acc), do: false

  defp handle_unique_key_violation(
         %{exception: %{postgres: %{code: :unique_violation}}},
         transactions_params_or_unique_numbers,
         data_type
       ) do
    block_numbers = data_to_block_numbers(transactions_params_or_unique_numbers, data_type)

    Block.set_refetch_needed(block_numbers)

    Logger.error(fn ->
      [
        "unique_violation on internal transactions import, #{data_type} identifiers: ",
        inspect(transactions_params_or_unique_numbers)
      ]
    end)
  end

  defp handle_unique_key_violation(_reason, _identifiers, _data_type), do: :ok

  defp handle_foreign_key_violation(internal_transactions_params, block_numbers_or_transactions, data_type) do
    block_numbers = data_to_block_numbers(block_numbers_or_transactions, data_type)

    Block.set_refetch_needed(block_numbers)

    transaction_hashes =
      internal_transactions_params
      |> Enum.map(&to_string(&1.transaction_hash))
      |> Enum.uniq()

    Logger.error(fn ->
      [
        "foreign_key_violation on internal transactions import, foreign transactions hashes: ",
        Enum.join(transaction_hashes, ", ")
      ]
    end)
  end

  defp handle_not_found_transaction(errors) when is_list(errors) do
    Enum.each(errors, &handle_not_found_transaction/1)
  end

  defp handle_not_found_transaction(error) do
    case error do
      %{data: data, message: "historical backend error" <> _} -> invalidate_block_from_error(data)
      %{data: data, message: "genesis is not traceable"} -> invalidate_block_from_error(data)
      %{data: data, message: "transaction not found"} -> invalidate_block_from_error(data)
      _ -> :ok
    end
  end

  defp invalidate_block_from_error(%{"blockNumber" => block_number}),
    do: Block.set_refetch_needed([block_number])

  defp invalidate_block_from_error(%{block_number: block_number}),
    do: Block.set_refetch_needed([block_number])

  defp invalidate_block_from_error(_error_data), do: :ok

  defp queue_data_type(_json_rpc_named_arguments) do
    # TODO: bring back after the migration of internal transactions PK to [:block_hash, :transaction_index, :index]
    # variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

    # if variant in block_traceable_variants() do
    #   :block_number
    # else
    #   :transaction_params
    # end

    if Application.get_env(:explorer, :non_existing_variable, false) do
      :transaction_params
    else
      :block_number
    end
  end

  defp data_to_block_numbers(block_numbers, :block_number), do: block_numbers

  defp data_to_block_numbers(transactions_params, :transaction_params) do
    transactions_params
    |> Enum.map(& &1.block_number)
    |> Enum.uniq()
  end

  def defaults do
    [
      poll: false,
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: Indexer.Fetcher.InternalTransaction.TaskSupervisor,
      metadata: [fetcher: :internal_transaction]
    ]
  end

  defp async_import_celo_token_balances(%{token_transfers: token_transfers, tokens: tokens}) do
    if Application.get_env(:explorer, :chain_type) == :celo do
      token_transfers_with_token = token_transfers_merge_token(token_transfers, tokens)

      address_token_balances =
        %{token_transfers_params: token_transfers_with_token}
        |> AddressTokenBalances.params_set()
        |> Enum.map(fn %{address_hash: address_hash, token_contract_address_hash: token_contract_address_hash} = entry ->
          with {:ok, address_hash} <- Hash.Address.cast(address_hash),
               {:ok, token_contract_address_hash} <- Hash.Address.cast(token_contract_address_hash) do
            entry
            |> Map.put(:address_hash, address_hash)
            |> Map.put(:token_contract_address_hash, token_contract_address_hash)
          else
            error -> Logger.error("Failed to cast string to hash: #{inspect(error)}")
          end
        end)

      async_import_token_balances(%{address_token_balances: address_token_balances}, false)
    else
      :ok
    end
  end
end
