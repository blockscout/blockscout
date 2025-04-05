defmodule Explorer.Migrator.SwitchPendingOperations do
  @moduledoc false

  use GenServer, restart: :transient

  alias Explorer.Chain.PendingOperationsHelper

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, state) do
    PendingOperationsHelper.maybe_transfuse_data()
    {:stop, :normal, state}
  end
end
