defmodule Indexer.Temporary.AddressesWithoutCode do
  @moduledoc """
  Temporary module to fetch contract code for addresses without it.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Repo
  alias Indexer.Block.Realtime.Fetcher
  alias Indexer.Temporary.AddressesWithoutCode.TaskSupervisor

  @task_options [max_concurrency: 3, timeout: :infinity]
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
    Logger.debug(
      [
        "Started query to fetch addresses without code"
      ],
      fetcher: :addresses_without_code
    )

    query =
      from(block in Block,
        left_join: transaction in Transaction,
        on: block.hash == transaction.block_hash,
        where:
          is_nil(transaction.to_address_hash) and is_nil(transaction.created_contract_address_hash) and
            block.consensus == true and is_nil(transaction.error) and not is_nil(transaction.hash),
        distinct: block.hash
      )

    found_blocks = Repo.all(query, timeout: @query_timeout)

    Logger.debug(
      [
        "Finished query to fetch blocks that  need to be re-fetched. Number of records is #{Enum.count(found_blocks)}"
      ],
      fetcher: :addresses_without_code
    )

    TaskSupervisor
    |> Task.Supervisor.async_stream_nolink(
      found_blocks,
      fn block -> refetch_block(block, fetcher) end,
      @task_options
    )
    |> Enum.to_list()
  end

  def refetch_block(block, fetcher) do
    Fetcher.fetch_and_import_block(block.number, fetcher, false)
  rescue
    e ->
      Logger.debug(
        [
          "Failed to fetch block #{to_string(block.hash)} #{block.number} because of #{inspect(e)}"
        ],
        fetcher: :addresses_without_code
      )
  end
end
