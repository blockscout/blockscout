defmodule Indexer.Fetcher.NonceUpdater do
  @moduledoc """
  Periodically updates addresses nonce
  """

  use GenServer

  require Logger

  alias Explorer.Chain

  @default_update_interval :timer.seconds(10)

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: Application.get_env(:indexer, :graceful_shutdown_period)
    }
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_next_update()

    {:ok, %{}}
  end

  def add(addresses_params) do
    GenServer.cast(__MODULE__, {:add, addresses_params})
  end

  def handle_cast({:add, addresses_params}, state) do
    params_map = Map.new(addresses_params, fn address -> {address.hash, address} end)

    result_state =
      Map.merge(state, params_map, fn _hash, old_address, new_address ->
        if new_address.nonce > old_address.nonce, do: new_address, else: old_address
      end)

    {:noreply, result_state}
  end

  def handle_info(:update, addresses_map) do
    addresses_params = Map.values(addresses_map)

    result_state =
      case Chain.import(%{addresses: %{params: addresses_params}, timeout: :infinity}) do
        {:ok, _} ->
          %{}

        error ->
          Logger.error("Failed to update addresses nonce: #{inspect(error)}, retrying")
          addresses_map
      end

    schedule_next_update()

    {:noreply, result_state}
  rescue
    exception ->
      error = Exception.format(:error, exception, __STACKTRACE__)
      Logger.error("Failed to update addresses nonce: #{error}, retrying")
      schedule_next_update()

      {:noreply, addresses_map}
  end

  def handle_info({_ref, _result}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp schedule_next_update do
    Process.send_after(self(), :update, @default_update_interval)
  end
end
