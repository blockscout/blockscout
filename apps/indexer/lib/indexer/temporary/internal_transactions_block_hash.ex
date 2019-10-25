defmodule Indexer.Temporary.InternalTransactionsBlockHash do
  @moduledoc """
  Temporary module to populate block hash for internal transactions.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias Explorer.Chain.{ InternalTransaction, Transaction}
  alias Explorer.Repo
  alias Indexer.Temporary.AddressesWithoutCode.TaskSupervisor

  @task_options [max_concurrency: 3, timeout: :infinity]
  @batch_size 500
  @query_timeout :infinity

  def start_link([gen_server_options]) do
    GenServer.start_link(__MODULE__, [], gen_server_options)
  end

  @impl GenServer
  def init(_opts) do
    schedule_work()

    :ok
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
      from(transaction in Transaction,
        left_join: internal_transaction in InternalTransaction,
        on: transaction.hash == internal_transaction.transaction_hash,
        where: is_nil(internal_transaction.block_hash) and not is_nil(internal_transaction.transaction_hash)
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
        fn transaction -> populate_block_hash(transaction) end,
        @task_options
      )

      Repo.transaction(fn -> Stream.run(stream) end, timeout: @query_timeout)
  end

  def populate_block_hash(transaction) do
    Repo.update(
      from(t in InternalTransaction, where: t.transaction_hash == ^transaction.hash),
      set: [block_hash: transaction.block_hash]
    )
  end
end
