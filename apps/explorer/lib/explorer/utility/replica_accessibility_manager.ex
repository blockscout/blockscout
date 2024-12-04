defmodule Explorer.Utility.ReplicaAccessibilityManager do
  @moduledoc """
  Module responsible for periodically checking replica accessibility.
  """

  use GenServer

  alias Explorer.Repo

  @interval :timer.seconds(10)

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    if System.get_env("DATABASE_READ_ONLY_API_URL") do
      schedule_next_check(0)

      {:ok, %{}}
    else
      :ignore
    end
  end

  def handle_info(:check, state) do
    check()
    schedule_next_check(@interval)

    {:noreply, state}
  end

  defp check do
    case Repo.replica_repo().query(query()) do
      {:ok, %{rows: [[is_slave, lag]]}} ->
        replica_inaccessible? = is_slave and :timer.seconds(lag || 0) > max_lag()
        set_replica_inaccessibility(replica_inaccessible?)

      _ ->
        set_replica_inaccessibility(true)
    end
  end

  defp query do
    """
    SELECT pg_is_in_recovery(), (
       EXTRACT(EPOCH FROM now()) -
       EXTRACT(EPOCH FROM pg_last_xact_replay_timestamp())
      )::int;
    """
  end

  defp max_lag do
    Application.get_env(:explorer, :replica_max_lag)
  end

  defp set_replica_inaccessibility(inaccessible?) do
    Application.put_env(:explorer, :replica_inaccessible?, inaccessible?)
  end

  defp schedule_next_check(interval) do
    Process.send_after(self(), :check, interval)
  end
end
