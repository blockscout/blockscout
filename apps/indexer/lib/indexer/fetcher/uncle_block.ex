defmodule Indexer.Fetcher.UncleBlock do
  @moduledoc """
  Fetches `t:Explorer.Chain.Block.t/0` by `hash` and updates `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`
  `uncle_fetched_at` where the `uncle_hash` matches `hash`.
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Ecto.Changeset
  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Indexer.{Block, BufferedTask, Tracer}
  alias Indexer.Fetcher.UncleBlock
  alias Indexer.Transform.Addresses

  @behaviour Block.Fetcher
  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 10,
    max_concurrency: 10,
    task_supervisor: Indexer.Fetcher.UncleBlock.TaskSupervisor,
    metadata: [fetcher: :block_uncle]
  ]

  @doc """
  Asynchronously fetches `t:Explorer.Chain.Block.t/0` for the given `hashes` and updates
  `t:Explorer.Chain.Block.SecondDegreeRelation.t/0` `block_fetched_at`.
  """
  @spec async_fetch_blocks([Hash.Full.t()]) :: :ok
  def async_fetch_blocks(block_hashes) when is_list(block_hashes) do
    BufferedTask.buffer(
      __MODULE__,
      block_hashes
      |> Enum.map(&to_string/1)
      |> Enum.uniq()
    )
  end

  @doc false
  def child_spec([init_options, gen_server_options]) when is_list(init_options) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :block_fetcher)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_options =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, %Block.Fetcher{state | broadcast: :uncle, callback_module: __MODULE__})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_options}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_unfetched_uncle_hashes(initial, fn uncle_hash, acc ->
        uncle_hash
        |> to_string()
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  @decorate trace(name: "fetch", resource: "Indexer.Fetcher.UncleBlock.run/2", service: :indexer, tracer: Tracer)
  def run(hashes, %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher) do
    # the same block could be included as an uncle on multiple blocks, but we only want to fetch it once
    unique_hashes = Enum.uniq(hashes)

    unique_hash_count = Enum.count(unique_hashes)
    Logger.metadata(count: unique_hash_count)

    Logger.debug("fetching")

    case EthereumJSONRPC.fetch_blocks_by_hash(unique_hashes, json_rpc_named_arguments) do
      {:ok, blocks} ->
        run_blocks(blocks, block_fetcher, unique_hashes)

      {:error, reason} ->
        Logger.error(
          fn ->
            ["failed to fetch: ", inspect(reason)]
          end,
          error_count: unique_hash_count
        )

        {:retry, unique_hashes}
    end
  end

  defp run_blocks(%Blocks{blocks_params: []}, _, original_entries), do: {:retry, original_entries}

  defp run_blocks(
         %Blocks{
           blocks_params: blocks_params,
           transactions_params: transactions_params,
           block_second_degree_relations_params: block_second_degree_relations_params,
           errors: errors
         },
         block_fetcher,
         original_entries
       ) do
    addresses_params = Addresses.extract_addresses(%{blocks: blocks_params, transactions: transactions_params})

    case Block.Fetcher.import(block_fetcher, %{
           addresses: %{params: addresses_params},
           blocks: %{params: blocks_params},
           block_second_degree_relations: %{params: block_second_degree_relations_params},
           transactions: %{params: transactions_params, on_conflict: :nothing}
         }) do
      {:ok, _} ->
        retry(errors)

      {:error, {:import = step, [%Changeset{} | _] = changesets}} ->
        Logger.error(fn -> ["Failed to validate: ", inspect(changesets)] end, step: step)

        {:retry, original_entries}

      {:error, {:import = step, reason}} ->
        Logger.error(fn -> inspect(reason) end, step: step)

        {:retry, original_entries}

      {:error, step, failed_value, _changes_so_far} ->
        Logger.error(fn -> ["failed to import: ", inspect(failed_value)] end,
          step: step,
          error_count: Enum.count(original_entries)
        )

        {:retry, original_entries}
    end
  end

  @ignored_options ~w(address_hash_to_fetched_balance_block_number)a

  @impl Block.Fetcher
  def import(_, options) when is_map(options) do
    with {:ok, %{block_second_degree_relations: block_second_degree_relations}} = ok <-
           options
           |> Map.drop(@ignored_options)
           |> uncle_blocks()
           |> fork_transactions()
           |> Chain.import() do
      # * CoinBalance.async_fetch_balances is not called because uncles don't affect balances
      # * InternalTransaction.async_fetch is not called because internal transactions are based on transaction
      #   hash, which is shared with transaction on consensus blocks.
      # * Token.async_fetch is not called because the tokens only matter on consensus blocks
      # * TokenBalance.async_fetch is not called because it uses block numbers from consensus, not uncles

      block_second_degree_relations
      |> Enum.map(& &1.uncle_hash)
      |> UncleBlock.async_fetch_blocks()

      ok
    end
  end

  defp uncle_blocks(chain_import_options) do
    put_in(chain_import_options, [:blocks, :params, Access.all(), :consensus], false)
  end

  defp fork_transactions(chain_import_options) do
    transactions_params = chain_import_options[:transactions][:params] || []

    chain_import_options
    |> put_in([:transactions, :params], forked_transactions_params(transactions_params))
    |> put_in([Access.key(:transaction_forks, %{}), :params], transaction_forks_params(transactions_params))
  end

  defp forked_transactions_params(transactions_params) do
    # With no block_hash, there will be a collision for the same hash when a transaction is used in more than 1 uncle,
    # so use MapSet to prevent duplicate row errors.
    MapSet.new(transactions_params, fn transaction_params ->
      Map.merge(transaction_params, %{
        block_hash: nil,
        block_number: nil,
        index: nil,
        gas_used: nil,
        cumulative_gas_used: nil,
        status: nil
      })
    end)
  end

  defp transaction_forks_params(transactions_params) do
    Enum.map(transactions_params, fn %{block_hash: uncle_hash, index: index, hash: hash} ->
      %{uncle_hash: uncle_hash, index: index, hash: hash}
    end)
  end

  defp retry([]), do: :ok

  defp retry(errors) when is_list(errors) do
    retried_entries = errors_to_entries(errors)
    loggable_errors = loggable_errors(errors)
    loggable_error_count = Enum.count(loggable_errors)

    unless loggable_error_count == 0 do
      Logger.error(
        fn ->
          [
            "failed to fetch: ",
            errors_to_iodata(loggable_errors)
          ]
        end,
        error_count: loggable_error_count
      )
    end

    {:retry, retried_entries}
  end

  defp loggable_errors(errors) when is_list(errors) do
    Enum.filter(errors, fn
      %{code: 404, message: "Not Found"} -> false
      _ -> true
    end)
  end

  defp errors_to_entries(errors) when is_list(errors) do
    Enum.map(errors, &error_to_entry/1)
  end

  defp error_to_entry(%{data: %{hash: hash}}) when is_binary(hash), do: hash

  defp errors_to_iodata(errors) when is_list(errors) do
    errors_to_iodata(errors, [])
  end

  defp errors_to_iodata([], iodata), do: iodata

  defp errors_to_iodata([error | errors], iodata) do
    errors_to_iodata(errors, [iodata | error_to_iodata(error)])
  end

  defp error_to_iodata(%{code: code, message: message, data: %{hash: hash}})
       when is_integer(code) and is_binary(message) and is_binary(hash) do
    [hash, ": (", to_string(code), ") ", message, ?\n]
  end
end
