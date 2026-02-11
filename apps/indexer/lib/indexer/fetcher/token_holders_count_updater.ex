defmodule Indexer.Fetcher.TokenHoldersCountUpdater do
  @moduledoc """
  Periodically updates token holder_count accumulated from imported current token balances
  """

  use GenServer

  require Logger

  alias Explorer.Chain.Import
  alias Explorer.Chain.Import.Runner.Tokens

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

  def add(upserted_balances) do
    GenServer.cast(__MODULE__, {:add, upserted_balances})
  end

  def handle_cast({:add, upserted_balances}, state) do
    new_state =
      upserted_balances
      |> upserted_balances_to_holder_count_deltas()
      |> Enum.reduce(state, fn %{contract_address_hash: contract_address_hash, delta: delta}, acc ->
        Map.update(acc, contract_address_hash, delta, &(&1 + delta))
      end)

    {:noreply, new_state}
  end

  def handle_info(:update, state) do
    Logger.info("TokenHoldersCountUpdater updating #{Enum.count(state)} tokens")

    result_state = do_update(state)
    schedule_next_update()
    {:noreply, result_state}
  rescue
    exception ->
      error = Exception.format(:error, exception, __STACKTRACE__)
      log_error(error)
      schedule_next_update()

      {:noreply, state}
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

  defp do_update(state) do
    token_holder_count_deltas =
      Enum.map(state, fn {hash, delta} ->
        %{contract_address_hash: hash, delta: delta}
      end)

    case Tokens.update_holder_counts_with_deltas(Repo, token_holder_count_deltas, %{
           timeout: :infinity,
           timestamps: Import.timestamps()
         }) do
      {:ok, _imported} ->
        Logger.info("TokenHoldersCountUpdater updated #{Enum.count(state)} holders count")
        %{}

      error ->
        log_error(inspect(error))
        state
    end
  end

  # Assumes existence of old_value field with previous value or nil
  defp upserted_balances_to_holder_count_deltas(upserted_balances) do
    upserted_balances
    |> Enum.map(fn %{token_contract_address_hash: contract_address_hash, value: value, old_value: old_value} ->
      delta =
        cond do
          not valid_holder?(old_value) and valid_holder?(value) -> 1
          valid_holder?(old_value) and not valid_holder?(value) -> -1
          true -> 0
        end

      %{contract_address_hash: contract_address_hash, delta: delta}
    end)
    |> Enum.group_by(& &1.contract_address_hash, & &1.delta)
    |> Enum.map(fn {contract_address_hash, deltas} ->
      %{contract_address_hash: contract_address_hash, delta: Enum.sum(deltas)}
    end)
    |> Enum.filter(fn %{delta: delta} -> delta != 0 end)
  end

  defp valid_holder?(value) do
    not is_nil(value) and Decimal.compare(value, 0) == :gt
  end

  defp schedule_next_update do
    Process.send_after(self(), :update, @default_update_interval)
  end

  defp log_error(error) do
    Logger.error("Failed to update token holders count: #{error}, retrying")
  end
end
