defmodule Indexer.Block.UncatalogedRewards.Processor do
  @moduledoc """
  genserver to find blocks without rewards and fetch their rewards in batches
  """

  use GenServer

  alias Explorer.Chain
  alias Indexer.Block.UncatalogedRewards.Importer

  @max_batch_size 150
  @default_cooldown 300

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(args) do
    send(self(), :import_batch)
    {:ok, args}
  end

  @impl true
  def handle_info(:import_batch, state) do
    @max_batch_size
    |> Chain.get_blocks_without_reward()
    |> import_or_try_later

    {:noreply, state}
  end

  defp import_or_try_later(batch) do
    import_results = Importer.fetch_and_import_rewards(batch)

    wait_time = if import_results == {:ok, []}, do: :timer.hours(24), else: @default_cooldown

    Process.send_after(self(), :import_batch, wait_time)
  end
end
