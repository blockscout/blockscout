defmodule Indexer.Fetcher.CurrentTokenBalanceImporter do
  @moduledoc """
  Periodically updates current token balances accumulated from block fetcher
  """

  use GenServer

  require Logger

  import Indexer.Block.Fetcher, only: [async_import_current_token_balances: 2]

  alias Explorer.Chain

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

  def add(ctb_params) do
    GenServer.cast(__MODULE__, {:add, ctb_params})
  end

  def handle_cast({:add, ctb_params}, state) do
    result_state =
      Enum.reduce(ctb_params, state, fn params, acc ->
        key = {params.address_hash, params.token_contract_address_hash, params.token_id}
        existing_record = state[key]

        if is_nil(existing_record) or existing_record.block_number <= params.block_number do
          Map.put(acc, key, params)
        else
          acc
        end
      end)

    {:noreply, result_state}
  end

  def handle_info(:update, ctb_map) do
    Logger.info("[CurrentTokenBalanceImporter] importing #{Enum.count(ctb_map)} balances")
    result_state = do_update(ctb_map)
    schedule_next_update()
    {:noreply, result_state}
  rescue
    exception ->
      error = Exception.format(:error, exception, __STACKTRACE__)
      log_error(error)
      schedule_next_update()

      {:noreply, ctb_map}
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

  defp do_update(ctb_map) do
    ctb_params = Map.values(ctb_map)

    case Chain.import(%{address_current_token_balances: %{params: ctb_params}, timeout: :infinity}) do
      {:ok, imported} ->
        Logger.info("[CurrentTokenBalanceImporter] imported #{Enum.count(ctb_params)} balances")
        async_import_current_token_balances(imported, true)

        %{}

      error ->
        log_error(inspect(error))
        ctb_map
    end
  end

  defp schedule_next_update do
    Process.send_after(self(), :update, @default_update_interval)
  end

  defp log_error(error) do
    Logger.error("[CurrentTokenBalanceImporter] Failed to update current token balances: #{error}, retrying")
  end
end
