defmodule Explorer.Migrator.SanitizeMissingBlockRanges do
  @moduledoc """
  Remove invalid missing block ranges (from_number < to_number and intersecting ones)
  """

  use GenServer, restart: :transient

  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Utility.MissingBlockRange

  @migration_name "sanitize_missing_ranges"

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}, {:continue, :ok}}
  end

  def handle_continue(:ok, state) do
    case MigrationStatus.get_status(@migration_name) do
      "completed" ->
        :ok

      _ ->
        MigrationStatus.set_status(@migration_name, "started")
        MissingBlockRange.sanitize_missing_block_ranges()
        MigrationStatus.set_status(@migration_name, "completed")
    end

    {:stop, :normal, state}
  end
end
