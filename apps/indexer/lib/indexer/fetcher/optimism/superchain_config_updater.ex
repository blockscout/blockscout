defmodule Indexer.Fetcher.Optimism.SuperchainConfigUpdater do
  @moduledoc """
  Runs once on startup to populate Optimism constants from Superchain TOML
  (with env fallback) into the `constants` table.
  """

  use GenServer

  require Logger

  alias Indexer.Fetcher.Optimism.SuperchainConfig

  @max_attempts 3
  @refresh_timeout_ms 20_000
  @retry_backoff_ms 2_000

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    state = %{attempt: 0}

    if Application.get_env(:explorer, :chain_type) == :optimism do
      {:ok, state, {:continue, :refresh}}
    else
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_continue(:refresh, state) do
    {:noreply, maybe_refresh(state)}
  end

  @impl GenServer
  def handle_info(:retry_refresh, state) do
    {:noreply, maybe_refresh(state)}
  end

  defp maybe_refresh(%{attempt: attempt} = state) do
    case refresh_with_timeout() do
      :ok ->
        state

      {:error, reason} ->
        next_attempt = attempt + 1

        if next_attempt < @max_attempts do
          Logger.warning(
            "Superchain config refresh failed (attempt #{next_attempt}/#{@max_attempts}): #{inspect(reason)}. Retrying in #{@retry_backoff_ms}ms."
          )

          Process.send_after(self(), :retry_refresh, @retry_backoff_ms)
          %{state | attempt: next_attempt}
        else
          Logger.error("Superchain config refresh failed after #{@max_attempts} attempts: #{inspect(reason)}")

          %{state | attempt: next_attempt}
        end
    end
  end

  defp refresh_with_timeout do
    task = Task.async(fn -> SuperchainConfig.refresh() end)

    try do
      case Task.await(task, @refresh_timeout_ms) do
        :ok -> :ok
        other -> {:error, {:unexpected_refresh_result, other}}
      end
    catch
      :exit, {:timeout, _} = timeout_reason ->
        Task.shutdown(task, :brutal_kill)
        {:error, timeout_reason}

      :exit, reason ->
        {:error, reason}
    end
  end
end
