defmodule Indexer.Temporary.UnclesWithoutIndex do
  @moduledoc """
  Fetches `index`es for unfetched `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`.
  As we don't explicitly store uncle block lists for nephew blocks, we need to refetch
  them completely.
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  import Ecto.Query

  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Block.SecondDegreeRelation
  alias Explorer.Chain.Cache.Uncles
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.UncleBlock

  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 100,
    max_concurrency: 10,
    task_supervisor: Indexer.Temporary.UnclesWithoutIndex.TaskSupervisor,
    metadata: [fetcher: :uncles_without_index]
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
      from(bsdr in SecondDegreeRelation,
        join: block in assoc(bsdr, :nephew),
        where: is_nil(bsdr.index) and is_nil(bsdr.uncle_fetched_at) and block.consensus == true,
        select: bsdr.nephew_hash,
        group_by: bsdr.nephew_hash
      )

    {:ok, final} =
      Repo.stream_reduce(query, initial, fn nephew_hash, acc ->
        nephew_hash
        |> to_string()
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  @decorate trace(name: "fetch", resource: "Indexer.Fetcher.UncleBlock.run/2", service: :indexer, tracer: Tracer)
  def run(hashes, json_rpc_named_arguments) do
    hash_count = Enum.count(hashes)
    Logger.metadata(count: hash_count)

    Logger.debug("fetching")

    case EthereumJSONRPC.fetch_blocks_by_hash(hashes, json_rpc_named_arguments) do
      {:ok, blocks} ->
        run_blocks(blocks, hashes)

      {:error, reason} ->
        Logger.error(
          fn ->
            ["failed to fetch: ", inspect(reason)]
          end,
          error_count: hash_count
        )

        {:retry, hashes}
    end
  end

  defp run_blocks(%Blocks{blocks_params: []}, original_entries), do: {:retry, original_entries}

  defp run_blocks(
         %Blocks{block_second_degree_relations_params: block_second_degree_relations_params, errors: errors},
         original_entries
       ) do
    case Chain.import(%{block_second_degree_relations: %{params: block_second_degree_relations_params}}) do
      {:ok, %{block_second_degree_relations: block_second_degree_relations}} ->
        UncleBlock.async_fetch_blocks(block_second_degree_relations)
        Uncles.update_from_second_degree_relations(block_second_degree_relations)

        retry(errors)

      {:error, step, failed_value, _changes_so_far} ->
        Logger.error(fn -> ["failed to import: ", inspect(failed_value)] end,
          step: step,
          error_count: Enum.count(original_entries)
        )

        {:retry, original_entries}
    end
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
