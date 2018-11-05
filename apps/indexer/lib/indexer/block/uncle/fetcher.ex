defmodule Indexer.Block.Uncle.Fetcher do
  @moduledoc """
  Fetches `t:Explorer.Chain.Block.t/0` by `hash` and updates `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`
  `uncle_fetched_at` where the `uncle_hash` matches `hash`.
  """

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Indexer.{AddressExtraction, Block, BufferedTask}

  @behaviour Block.Fetcher
  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 2,
    max_concurrency: 2,
    task_supervisor: Indexer.Block.Uncle.TaskSupervisor
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
  def run(hashes, %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher) do
    # the same block could be included as an uncle on multiple blocks, but we only want to fetch it once
    unique_hashes = Enum.uniq(hashes)

    Logger.debug(fn -> "fetching #{length(unique_hashes)} uncle blocks" end)

    case EthereumJSONRPC.fetch_blocks_by_hash(unique_hashes, json_rpc_named_arguments) do
      {:ok,
       %{
         blocks: blocks_params,
         transactions: transactions_params,
         block_second_degree_relations: block_second_degree_relations_params
       }} ->
        addresses_params =
          AddressExtraction.extract_addresses(%{blocks: blocks_params, transactions: transactions_params})

        case Block.Fetcher.import(block_fetcher, %{
               addresses: %{params: addresses_params},
               blocks: %{params: blocks_params},
               block_second_degree_relations: %{params: block_second_degree_relations_params},
               transactions: %{params: transactions_params, on_conflict: :nothing}
             }) do
          {:ok, _} ->
            :ok

          {:error, step, failed_value, _changes_so_far} ->
            Logger.error(fn ->
              [
                "failed to import ",
                unique_hashes |> length() |> to_string(),
                "uncle blocks in step ",
                inspect(step),
                ": ",
                inspect(failed_value)
              ]
            end)

            {:retry, unique_hashes}
        end

      {:error, reason} ->
        Logger.error(fn ->
          ["failed to fetch ", unique_hashes |> length |> to_string(), " uncle blocks: ", inspect(reason)]
        end)

        {:retry, unique_hashes}
    end
  end

  @ignored_options ~w(address_hash_to_fetched_balance_block_number transaction_hash_to_block_number)a

  @impl Block.Fetcher
  def import(_, options) when is_map(options) do
    with {:ok, %{block_second_degree_relations: block_second_degree_relations}} = ok <-
           options
           |> Map.drop(@ignored_options)
           |> uncle_blocks()
           |> fork_transactions()
           |> Chain.import() do
      # * CoinBalance.Fetcher.async_fetch_balances is not called because uncles don't affect balances
      # * InternalTransaction.Fetcher.async_fetch is not called because internal transactions are based on transaction
      #   hash, which is shared with transaction on consensus blocks.
      # * Token.Fetcher.async_fetch is not called because the tokens only matter on consensus blocks
      # * TokenBalance.Fetcher.async_fetch is not called because it uses block numbers from consensus, not uncles

      block_second_degree_relations
      |> Enum.map(& &1.uncle_hash)
      |> Block.Uncle.Fetcher.async_fetch_blocks()

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
end
