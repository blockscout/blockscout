defmodule Indexer.Temporary.InternalTransactionsBlockHash do
  @moduledoc """
  Temporary module to populate block hash for internal transactions.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias Explorer.Chain.{Block, InternalTransaction, Transaction}
  alias Explorer.Repo
  alias Indexer.Temporary.InternalTransactionsBlockHash.TaskSupervisor

  @task_options [max_concurrency: 3, timeout: :infinity]
  @query_timeout :infinity
  @batch_size 10

  def start_link(gen_server_options) do
    GenServer.start_link(__MODULE__, [], gen_server_options)
  end

  @impl GenServer
  def init(_opts) do
    schedule_work()

    {:ok, []}
  end

  def schedule_work do
    Process.send_after(self(), :run, 1_000)
  end

  @impl GenServer
  def handle_info(:run, _) do
    populate_block_hash()

    {:noreply, []}
  end

  def populate_block_hash do
    Logger.debug(
      [
        "Started populating block_hashes for internal transactions"
      ],
      fetcher: :internal_transacions_block_hash
    )

    query =
      from(block in Block,
        inner_join: transaction in Transaction,
        on: block.hash == transaction.block_hash,
        inner_join: internal_transaction in InternalTransaction,
        on: transaction.hash == internal_transaction.transaction_hash,
        where: is_nil(internal_transaction.block_hash) and not is_nil(internal_transaction.transaction_hash),
        select: block.hash
      )

    Logger.debug(
      [
        "Started populating block hashes"
      ],
      fetcher: :internal_transacions_block_hash
    )

    process_query(query)
  end

  defp process_query(query) do
    query_stream = Repo.stream(query, max_rows: @batch_size, timeout: @query_timeout)

    stream =
      TaskSupervisor
      |> Task.Supervisor.async_stream_nolink(
        query_stream,
        fn block_hash -> populate_block_hash(block_hash) end,
        @task_options
      )

    Repo.transaction(fn -> Stream.run(stream) end, timeout: @query_timeout)
  end

  def populate_block_hash(block_hash) do
    Repo.update_all(
      from(it in InternalTransaction,
        inner_join: transaction in Transaction,
        on: it.transaction_hash == transaction.hash,
        where: transaction.block_hash == ^block_hash
      ),
      set: [block_hash: block_hash]
    )
  end
end
