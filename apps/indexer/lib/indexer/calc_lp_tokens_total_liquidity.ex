defmodule Indexer.CalcLpTokensTotalLiqudity do
  @moduledoc """
  Peiodically updates LP tokens total liquidity
  """

  use GenServer

  require Logger

  alias Explorer.Chain

  @interval :timer.minutes(10)

  def start_link([init_opts, gen_server_opts]) do
    start_link(init_opts, gen_server_opts)
  end

  def start_link(init_opts, gen_server_opts) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  @impl GenServer
  def init(opts) do
    interval = opts[:interval] || @interval

    Process.send_after(self(), :calc_total_liqudity, interval)

    {:ok, %{interval: interval}}
  end

  @impl GenServer
  def handle_info(:calc_total_liqudity, %{interval: interval} = state) do
    Logger.debug(fn -> "Calc LP tokens total liquidity" end)

    calc_total_liqudity()

    Process.send_after(self(), :calc_total_liqudity, interval)

    {:noreply, state}
  end

  # don't handle other messages (e.g. :ssl_closed)
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp calc_total_liqudity do
    Chain.calc_lp_tokens_total_liqudity()

    Logger.debug(fn -> "Total liqudity fetched for LP tokens" end)
  end
end
