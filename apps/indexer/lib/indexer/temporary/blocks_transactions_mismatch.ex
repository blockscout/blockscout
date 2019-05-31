defmodule Indexer.Temporary.BlocksTransactionsMismatch do
  @moduledoc """
  Fetches `consensus` `t:Explorer.Chain.Block.t/0` and compares their transaction
  number against a node, to revoke `consensus` on mismatch.

  This is meant to fix incorrectly strored transactions that happened as a result
  of a race condition due to the asynchronicity of indexer's components.
  """

  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  alias Ecto.Multi
  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain.Block
  alias Explorer.Repo
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 10,
    max_concurrency: 1,
    task_supervisor: Indexer.Temporary.BlocksTransactionsMismatch.TaskSupervisor,
    metadata: [fetcher: :blocks_transactions_mismatch]
  ]

  @doc false
  def child_spec([init_options, gen_server_options]) when is_list(init_options) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_options =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_options}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    query =
      from(block in Block,
        left_join: transactions in assoc(block, :transactions),
        where: block.consensus and block.refetch_needed,
        group_by: block.hash,
        select: {block, count(transactions.hash)}
      )

    {:ok, final} = Repo.stream_reduce(query, initial, &reducer.(&1, &2))

    final
  end

  @impl BufferedTask
  def run(blocks_data, json_rpc_named_arguments) do
    hashes = Enum.map(blocks_data, fn {block, _trans_num} -> block.hash end)

    Logger.debug("fetching")

    case EthereumJSONRPC.fetch_blocks_by_hash(hashes, json_rpc_named_arguments) do
      {:ok, blocks} ->
        run_blocks(blocks, blocks_data)

      {:error, reason} ->
        Logger.error(fn -> ["failed to fetch: ", inspect(reason)] end)
        {:retry, blocks_data}
    end
  end

  defp run_blocks(%Blocks{blocks_params: []}, blocks_data), do: {:retry, blocks_data}

  defp run_blocks(
         %Blocks{transactions_params: transactions_params, blocks_params: blocks_params},
         blocks_data
       ) do
    blocks_with_transactions_map =
      transactions_params
      |> Enum.group_by(&Map.fetch!(&1, :block_hash))
      |> Map.new(fn {block_hash, trans_lst} -> {block_hash, Enum.count(trans_lst)} end)

    found_blocks_map =
      blocks_params
      |> Map.new(&{Map.fetch!(&1, :hash), 0})
      |> Map.merge(blocks_with_transactions_map)

    {found_blocks_data, missing_blocks_data} =
      Enum.split_with(blocks_data, fn {block, _trans_num} ->
        Map.has_key?(found_blocks_map, to_string(block.hash))
      end)

    {:ok, _} =
      found_blocks_data
      |> Enum.reduce(Multi.new(), fn {block, trans_num}, multi ->
        changes = %{
          refetch_needed: false,
          consensus: found_blocks_map[to_string(block.hash)] == trans_num
        }

        Multi.update(multi, block.hash, Block.changeset(block, changes))
      end)
      |> Repo.transaction()

    if Enum.empty?(missing_blocks_data) do
      :ok
    else
      {:retry, missing_blocks_data}
    end
  end
end
