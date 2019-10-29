defmodule Indexer.Temporary.InternalTransactionsBlockHash do
  @moduledoc """
  Temporary module to populate block hash for internal transactions.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias Explorer.Chain.{Block, InternalTransaction, Transaction}
  alias Explorer.Repo

  @query_timeout :infinity
  @batch_size 10
  @limit 100

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
        distinct: block.hash,
        limit: @limit
      )

    Logger.debug(
      [
        "Started populating block hashes"
      ],
      fetcher: :internal_transacions_block_hash
    )

    process_query(query)

    Logger.debug(
      [
        "Finished populating block hashes"
      ],
      fetcher: :internal_transacions_block_hash
    )
  end

  defp process_query(query) do
    query = from(el in query, select: el.hash)

    query_stream = Repo.stream(query, max_rows: @batch_size, timeout: @query_timeout)

    stream =
      query_stream
      |> Stream.each(fn block_hash ->
        populate_block_hash(block_hash)
      end)

    Repo.transaction(fn -> Stream.run(stream) end, timeout: @query_timeout)

    Process.send_after(self(), :run, 1_000)
  end

  defp populate_block_hash(block_hash) do
    Logger.debug(
      [
        "Started populating block hash #{block_hash}"
      ],
      fetcher: :internal_transacions_block_hash
    )

    Repo.update_all(
      from(it in InternalTransaction,
        inner_join: transaction in Transaction,
        on: it.transaction_hash == transaction.hash,
        where: transaction.block_hash == ^block_hash
      ),
      set: [block_hash: block_hash]
    )

    Logger.debug(
      [
        "Finished populating block hash #{block_hash}"
      ],
      fetcher: :internal_transacions_block_hash
    )
  end
end
