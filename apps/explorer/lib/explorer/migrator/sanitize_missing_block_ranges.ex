defmodule Explorer.Migrator.SanitizeMissingBlockRanges do
  @moduledoc """
  Remove invalid missing block ranges (from_number < to_number and intersecting ones)
  """

  use GenServer

  alias Explorer.Utility.MissingBlockRange

  @interval :timer.minutes(5)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_sanitize()
    {:ok, %{}}
  end

  def handle_info(:sanitize, state) do
    MissingBlockRange.sanitize_missing_block_ranges()
    schedule_sanitize()

    {:noreply, state}
  end

  defp schedule_sanitize do
    Process.send_after(self(), :sanitize, @interval)
  end
end
