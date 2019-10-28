defmodule Indexer.Temporary.InternalTransactionsBlockHash do
  @moduledoc """
  Temporary module to populate block hash for internal transactions.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias Explorer.Chain.{InternalTransaction, Transaction}
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
      from(block in Block,
        inner_join: transaction in Transaction,
        on: block.hash == transaction.block_hash,
        inner_join: internal_transaction in InternalTransaction,
        on: transaction.hash == internal_transaction.transaction_hash,
        where: is_nil(internal_transaction.block_hash) and not is_nil(internal_transaction.transaction_hash),
        select: block.block_hash,
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
    transaction_hashes = Repo.all(query, timeout: @query_timeout)

    Repo.update(
      from(t in InternalTransaction, where: t.transaction_hash in ^transaction_hashes
        inner_jo
      ),
      set: [block_hash: transaction.block_hash]
    )
  end
end
