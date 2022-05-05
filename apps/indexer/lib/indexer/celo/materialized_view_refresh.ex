defmodule Indexer.Fetcher.CeloMaterializedViewRefresh do
  @moduledoc """
  Periodically refreshes Celo relevant Materialized Views
  """
  use GenServer

  require Logger

  alias Explorer.Repo
  require Explorer.Celo.Telemetry, as: Telemetry

  @refresh_interval :timer.seconds(150)
  @timeout :timer.seconds(120)

  @daily_refresh_interval :timer.hours(24)
  @daily_timeout :timer.minutes(60)

  def start_link([init_opts, gen_server_opts]) do
    start_link(init_opts, gen_server_opts)
  end

  def start_link(init_opts, gen_server_opts) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  def init(opts) do
    refresh_interval = opts[:refresh_interval] || @refresh_interval
    timeout = opts[:timeout] || @timeout

    daily_refresh_interval = opts[:daily_refresh_interval] || @daily_refresh_interval
    daily_timeout = opts[:daily_timeout] || @daily_timeout

    Process.send_after(self(), :refresh_views, refresh_interval)
    Process.send_after(self(), :daily_refresh_views, daily_refresh_interval)

    {:ok,
     %{
       refresh_interval: refresh_interval,
       timeout: timeout,
       daily_refresh_interval: daily_refresh_interval,
       daily_timeout: daily_timeout
     }}
  end

  def handle_info(:refresh_views, %{refresh_interval: refresh_interval, timeout: timeout} = state) do
    Telemetry.wrap(:refresh_materialized_views, refresh_views(timeout))

    Process.send_after(self(), :refresh_views, refresh_interval)

    {:noreply, state}
  end

  def handle_info(:daily_refresh_views, %{daily_refresh_interval: refresh_interval, daily_timeout: timeout} = state) do
    Telemetry.wrap(:refresh_materialized_views_daily, daily_refresh_views(timeout))

    Process.send_after(self(), :daily_refresh_views, refresh_interval)

    {:noreply, state}
  end

  defp refresh_views(timeout) do
    Repo.query!("refresh materialized view celo_wallet_accounts;", [], timeout: timeout)
    Repo.query!("refresh materialized view celo_accumulated_rewards;", [], timeout: timeout)

    Logger.info(fn ->
      ["Refreshed material views."]
    end)
  end

  defp daily_refresh_views(timeout) do
    Repo.query!("refresh materialized view smart_contracts_transaction_counts;", [], timeout: timeout)

    Logger.info(fn ->
      ["Refreshed daily materialized views."]
    end)
  end
end
