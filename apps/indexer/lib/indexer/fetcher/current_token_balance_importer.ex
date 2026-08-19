# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.CurrentTokenBalanceImporter do
  @moduledoc """
  Periodically updates current token balances accumulated from block fetcher
  """

  use GenServer

  require Logger

  alias Explorer.Chain
  alias Indexer.Block.Fetcher

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
    Process.flag(:trap_exit, true)
    schedule_next_update()

    {:ok, %{}}
  end

  def add(ctb_params, realtime? \\ false) do
    GenServer.cast(__MODULE__, {:add, ctb_params, realtime?})
  end

  def handle_cast({:add, ctb_params, realtime?}, state) do
    result_state =
      Enum.reduce(ctb_params, state, fn params, acc ->
        key = {params.address_hash, params.token_contract_address_hash, params.token_id}
        existing_record = acc[key]

        cond do
          is_nil(existing_record) ->
            Map.put(acc, key, {params, realtime?})

          elem(existing_record, 0).block_number <= params.block_number ->
            Map.put(acc, key, {params, elem(existing_record, 1) or realtime?})

          true ->
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

  def handle_info({:EXIT, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  def terminate(reason, state) do
    log_error(reason)
    do_update(state)
  end

  defp do_update(ctb_map) when ctb_map == %{}, do: ctb_map

  defp do_update(ctb_map) do
    ctb_params =
      ctb_map
      |> Map.values()
      |> Enum.map(&elem(&1, 0))

    case Chain.import(%{address_current_token_balances: %{params: ctb_params}, timeout: :infinity}) do
      {:ok, %{address_current_token_balances: imported}} ->
        {realtime_imported, catchup_imported} =
          Enum.split_with(
            imported,
            &elem(ctb_map[{&1.address_hash, &1.token_contract_address_hash, &1.token_id}] || {nil, false}, 1)
          )

        Fetcher.async_import_current_token_balances(%{address_current_token_balances: realtime_imported}, true)
        Fetcher.async_import_current_token_balances(%{address_current_token_balances: catchup_imported}, false)

        Logger.info("[CurrentTokenBalanceImporter] imported #{Enum.count(ctb_params)} balances")

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
    Logger.error("[CurrentTokenBalanceImporter] Failed to update current token balances: #{inspect(error)}, retrying")
  end
end
