defmodule Indexer.Fetcher.MultichainSearchDb.CountersFetcher do
  @moduledoc """
  Fetches counters and adds them to a queue to send to Multichain Search DB service.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.{Address, Transaction}
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Chain.Transaction.History.{Historian, TransactionStats}
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Repo

  @fetcher_name :multichain_search_db_counters_fetcher

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{}, {:continue, nil}}
  end

  @impl GenServer
  def handle_continue(_, _state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two-second pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    Process.send(self(), :try_to_fetch_yesterday_counters, [])

    {:noreply, %{}}
  end

  @impl GenServer
  def handle_info(:try_to_fetch_yesterday_counters, _state) do
    today = Date.utc_today()
    yesterday = Date.add(today, -1)

    Logger.info("Waiting for transaction stats to be collected for #{yesterday}...")

    last_save_records_date =
      Historian.transaction_stats_last_save_records_timestamp()
      |> LastFetchedCounter.get()
      |> Decimal.to_integer()
      |> DateTime.from_unix!()
      |> DateTime.to_date()

    if last_save_records_date == today do
      # Historian module worked today, so we can use its results
      # for yesterday's number of transactions
      number_of_transactions =
        yesterday
        |> TransactionStats.by_date_range(yesterday)
        |> Enum.at(0, %{})
        |> Map.get(:number_of_transactions, 0)

      Process.send(self(), :fetch_yesterday_counters, [])

      {:noreply, %{number_of_transactions: number_of_transactions, yesterday: yesterday}}
    else
      # the stats is not ready yet, so wait for 1 minute and try again
      Process.send_after(self(), :try_to_fetch_yesterday_counters, 60_000)
      {:noreply, %{}}
    end
  end

  @impl GenServer
  def handle_info(:fetch_yesterday_counters, %{number_of_transactions: number_of_transactions, yesterday: yesterday}) do
    yesterday_dt = DateTime.new!(yesterday, Time.new!(23, 59, 59, 0))

    daily_transactions_number = number_of_transactions

    total_transactions_number =
      Repo.aggregate(
        from(t in Transaction, where: t.block_timestamp <= ^yesterday_dt and t.block_consensus == true),
        :count,
        :hash,
        timeout: :infinity
      )

    total_addresses_number =
      Repo.aggregate(from(a in Address, where: a.inserted_at <= ^yesterday_dt), :count, timeout: :infinity)

    Logger.info("Transaction stats is now available for #{yesterday}:")
    Logger.info("daily_transactions_number = #{daily_transactions_number}")
    Logger.info("total_transactions_number = #{total_transactions_number}")
    Logger.info("total_addresses_number = #{total_addresses_number}")

    MultichainSearch.send_counters_to_queue(
      %{
        yesterday_dt => %{
          daily_transactions_number: to_string(daily_transactions_number),
          total_transactions_number: to_string(total_transactions_number),
          total_addresses_number: to_string(total_addresses_number)
        }
      },
      :global
    )

    Logger.info("Waiting for the next day...")
    Process.send_after(self(), :try_to_fetch_yesterday_counters, calculate_delay_until_next_midnight())

    {:noreply, %{}}
  end

  defp calculate_delay_until_next_midnight do
    now = DateTime.utc_now()
    tomorrow = DateTime.new!(Date.add(Date.utc_today(), 1), Time.new!(0, 0, 1, 0), now.time_zone)

    DateTime.diff(tomorrow, now, :millisecond)
  end
end
