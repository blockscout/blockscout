defmodule Indexer.PendingOpsCleaner do
  @moduledoc """
  Periodically cleans non-consensus pending ops.
  """

  use GenServer

  require Logger

  alias Explorer.Chain

  @interval :timer.minutes(60)

  def start_link([init_opts, gen_server_opts]) do
    start_link(init_opts, gen_server_opts)
  end

  def start_link(init_opts, gen_server_opts) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  def init(opts) do
    interval = opts[:interval] || @interval

    Process.send_after(self(), :clean_nonconsensus_pending_ops, interval)

    {:ok, %{interval: interval}}
  end

  def handle_info(:clean_nonconsensus_pending_ops, %{interval: interval} = state) do
    Logger.debug(fn -> "Cleaning non-consensus pending ops" end)

    clean_nonconsensus_pending_ops()

    Process.send_after(self(), :clean_nonconsensus_pending_ops, interval)

    {:noreply, state}
  end

  defp clean_nonconsensus_pending_ops do
    :ok = Chain.remove_nonconsensus_blocks_from_pending_ops()

    Logger.debug(fn -> "Non-consensus pending ops are cleaned" end)
  end
end
