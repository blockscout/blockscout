defmodule Indexer.Temporary.NonConsensusBlocks do
  @moduledoc """
  Temporary module to refetch blocks, which are in main chain despite being non-consensus.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias Explorer.Chain.Block
  alias Explorer.Repo
  alias Indexer.Block.Realtime.Fetcher
  alias Indexer.Temporary.NonConsensusBlocks.TaskSupervisor

  @task_options [max_concurrency: 3, timeout: :infinity]
  @batch_size 10
  @query_timeout :infinity

  def start_link([fetcher, gen_server_options]) do
    GenServer.start_link(__MODULE__, fetcher, gen_server_options)
  end

  @impl GenServer
  def init(fetcher) do
    schedule_work()

    {:ok, fetcher}
  end

  def schedule_work do
    Process.send_after(self(), :run, 1_000)
  end

  @impl GenServer
  def handle_info(:run, fetcher) do
    run(fetcher)

    {:noreply, fetcher}
  end

  def run(fetcher) do
    Indexer.Logger.metadata(
      fn ->
        Logger.debug("Started non-consensus block re-fetcher")

        query =
          from(block in Block,
            left_join: parent_block in Block,
            on: block.parent_hash == parent_block.hash and parent_block.consensus,
            where: block.number > 0 and block.consensus and is_nil(parent_block.hash)
          )

        query_stream = Repo.stream(query, max_rows: @batch_size, timeout: @query_timeout)

        stream =
          TaskSupervisor
          |> Task.Supervisor.async_stream_nolink(
            query_stream,
            fn block -> refetch_block_parent(block, fetcher) end,
            @task_options
          )

        Repo.transaction(fn -> Stream.run(stream) end, timeout: @query_timeout)
      end,
      fetcher: :non_consensus_blocks
    )
  end

  def refetch_block_parent(block, fetcher) do
    Logger.debug(fn -> "Refetching block #{block.number - 1}" end)

    Fetcher.fetch_and_import_block(block.number - 1, fetcher, false)

    Logger.debug(fn -> "Finished refetching block #{block.number - 1}" end)
  rescue
    e ->
      Logger.debug(fn -> "Failed to refetch block #{block.number - 1}: #{inspect(e)}" end)
  end
end
