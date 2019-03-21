defmodule Indexer.Temporary.AddressesWithoutCode do
  @moduledoc """
  Temporary module to fetch contract code for addresses without it.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.Repo
  alias Indexer.Block.Realtime.Fetcher
  alias Indexer.Temporary.AddressesWithoutCode.TaskSupervisor

  @task_options [max_concurrency: 3, timeout: :infinity]
  @batch_size 500
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
    fix_transaction_without_to_address_and_created_contract_address(fetcher)
    fix_addresses_with_creation_transaction_but_without_code(fetcher)
  end

  def fix_transaction_without_to_address_and_created_contract_address(fetcher) do
    Logger.debug(
      [
        "Started fix_transaction_without_to_address_and_created_contract_address"
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

    process_query(query, fetcher)

    Logger.debug(
      [
        "Started fix_transaction_without_to_address_and_created_contract_address"
      ],
      fetcher: :addresses_without_code
    )
  end

  def fix_addresses_with_creation_transaction_but_without_code(fetcher) do
    Logger.debug(
      [
        "Started fix_addresses_with_creation_transaction_but_without_code"
      ],
      fetcher: :addresses_without_code
    )

    second_query =
      from(block in Block,
        left_join: transaction in Transaction,
        on: transaction.block_hash == block.hash,
        left_join: address in Address,
        on: address.hash == transaction.created_contract_address_hash,
        where:
          not is_nil(transaction.block_hash) and not is_nil(transaction.created_contract_address_hash) and
            is_nil(address.contract_code) and
            block.consensus == true and is_nil(transaction.error) and not is_nil(transaction.hash),
        distinct: block.hash
      )

    process_query(second_query, fetcher)

    Logger.debug(
      [
        "Finished fix_addresses_with_creation_transaction_but_without_code"
      ],
      fetcher: :addresses_without_code
    )
  end

  defp process_query(query, fetcher) do
    query_stream = Repo.stream(query, max_rows: @batch_size, timeout: @query_timeout)

    stream =
      TaskSupervisor
      |> Task.Supervisor.async_stream_nolink(
        query_stream,
        fn block -> refetch_block(block, fetcher) end,
        @task_options
      )

    Repo.transaction(fn -> Stream.run(stream) end)
  end

  def refetch_block(block, fetcher) do
    Logger.debug(
      [
        "Processing block #{to_string(block.hash)} #{block.number}"
      ],
      fetcher: :addresses_without_code
    )

    Fetcher.fetch_and_import_block(block.number, fetcher, false)

    Logger.debug(
      [
        "Finished processing block #{to_string(block.hash)} #{block.number}"
      ],
      fetcher: :addresses_without_code
    )
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
