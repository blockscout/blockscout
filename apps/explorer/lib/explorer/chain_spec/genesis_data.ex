defmodule Explorer.ChainSpec.GenesisData do
  @moduledoc """
  Fetches genesis data.
  """

  use GenServer

  require Logger

  alias Explorer.ChainSpec.Parity.Importer

  @interval :timer.minutes(2)

  @impl GenServer
  def init(_) do
    :timer.send_interval(@interval, :import)

    {:ok, %{}}
  end

  # Callback for errored fetch
  @impl GenServer
  def handle_info({_ref, {:error, reason}}, state) do
    Logger.warn(fn -> "Failed to fetch genesis data '#{reason}'." end)

    fetch_genesis_data()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:import, state) do
    Logger.debug(fn -> "Importing genesis data" end)

    fetch_genesis_data()

    {:noreply, state}
  end

  # Callback that a monitored process has shutdown
  @impl GenServer
  def handle_info({:DOWN, _, :process, _, _}, state) do
    {:noreply, state}
  end

  # Callback for successful fetch
  @impl GenServer
  def handle_info({_ref, _}, state) do
    {:noreply, state}
  end

  # sobelow_skip ["Traversal"]
  def fetch_genesis_data do
    if Application.get_env(:explorer, __MODULE__)[:chain_spec_path] do
      Task.Supervisor.async_nolink(Explorer.GenesisDataTaskSupervisor, fn ->
        chain_spec = Application.get_env(:explorer, __MODULE__)[:chain_spec_path] |> File.read!() |> Jason.decode!()
        Importer.import_emission_rewards(chain_spec)

        {:ok, _} = Importer.import_genesis_coin_balances(chain_spec)
      end)
    end
  end
end
