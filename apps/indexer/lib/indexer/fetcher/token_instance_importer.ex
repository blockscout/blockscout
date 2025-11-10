defmodule Indexer.Fetcher.TokenInstanceImporter do
  @moduledoc """
  Periodically updates token instances accumulated from block fetcher
  """

  use GenServer

  require Logger

  alias Explorer.Chain
  alias Indexer.Block.Fetcher
  alias Indexer.Transform.TokenInstances

  @default_update_interval :timer.minutes(1)

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

  def add(token_transfers_params) do
    GenServer.cast(__MODULE__, {:add, token_transfers_params})
  end

  def handle_cast({:add, token_transfers_params}, state) do
    result_state =
      %{token_transfers_params: token_transfers_params}
      |> TokenInstances.params_set(state)
      |> Map.new(&{{&1.token_contract_address_hash, &1.token_id}, &1})

    {:noreply, result_state}
  end

  def handle_info(:update, token_instances_map) do
    Logger.info("TokenInstanceImporter importing #{Enum.count(token_instances_map)} token instances")
    result_state = do_update(token_instances_map)
    schedule_next_update()
    {:noreply, result_state}
  rescue
    exception ->
      error = Exception.format(:error, exception, __STACKTRACE__)
      log_error(error)
      schedule_next_update()

      {:noreply, token_instances_map}
  end

  def handle_info({_ref, _result}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    do_update(state)
  end

  defp do_update(token_instances_map) do
    token_instances_params = Map.values(token_instances_map)

    case Chain.import(%{token_instances: %{params: token_instances_params}, timeout: :infinity}) do
      {:ok, imported} ->
        Logger.info("TokenInstanceImporter imported #{Enum.count(token_instances_params)} token instances")

        %{}

      error ->
        log_error(inspect(error))
        token_instances_map
    end
  end

  defp schedule_next_update do
    Process.send_after(self(), :update, @default_update_interval)
  end

  defp log_error(error) do
    Logger.error("Failed to update token instances: #{error}, retrying")
  end
end
