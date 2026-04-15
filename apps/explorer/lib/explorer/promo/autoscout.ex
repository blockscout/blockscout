defmodule Explorer.Promo.Autoscout do
  @moduledoc """
  Module responsible for logging the Autoscout promo message on application startup.
  """

  require Logger

  use GenServer

  @autoscout_promo """


   █   █     ███  █   █ █████  ███   ████  ████  ███  █   █ █████
  █     █   █   █ █   █   █   █   █ █     █     █   █ █   █   █
  █  █  █   █████ █   █   █   █   █  ███  █     █   █ █   █   █
  █  █  █   █   █ █   █   █   █   █     █ █     █   █ █   █   █
  █     █   █   █  ███    █    ███  ████   ████  ███   ███    █

  Deploy Blockscout explorer in 5 minutes at deploy.blockscout.com
  """

  def start_link(_) do
    Logger.info(@autoscout_promo)
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    Process.send_after(self(), :promo, :timer.seconds(10))

    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:promo, state) do
    promo()
    {:noreply, state}
  end

  defp promo do
    Logger.info(@autoscout_promo)
  end
end
