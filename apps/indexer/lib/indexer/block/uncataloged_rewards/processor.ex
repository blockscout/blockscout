defmodule Indexer.Block.UncatalogedRewards.Processor do
  @moduledoc """
  genserver to find blocks without rewards and fetch their rewards in batches
  """

  use GenServer

  alias Explorer.Chain
  alias Indexer.Block.UncatalogedRewards.Importer

  @max_batch_size 150
  @default_cooldown 300

  @doc false
  def child_spec([json_rpc_named_arguments, gen_server_options]) do
    Supervisor.child_spec({__MODULE__, [json_rpc_named_arguments, gen_server_options]}, id: __MODULE__)
  end

  def start_link(init_options, gen_server_options) do
    GenServer.start_link(__MODULE__, init_options, gen_server_options)
  end

  @impl GenServer
  def init(json_rpc_named_arguments) do
    {:ok, json_rpc_named_arguments, {:continue, :import_batch}}
  end

  @impl GenServer
  def handle_continue(:import_batch, json_rpc_named_arguments) do
    import_batch(json_rpc_named_arguments)

    {:noreply, json_rpc_named_arguments}
  end

  @impl GenServer
  def handle_info(:import_batch, json_rpc_named_arguments) do
    import_batch(json_rpc_named_arguments)

    {:noreply, json_rpc_named_arguments}
  end

  defp import_batch(json_rpc_named_arguments) do
    @max_batch_size
    |> Chain.get_blocks_without_reward()
    |> import_or_try_later(json_rpc_named_arguments)
  end

  defp import_or_try_later(batch, json_rpc_named_arguments) do
    import_results = Importer.fetch_and_import_rewards(batch, json_rpc_named_arguments)

    wait_time = if import_results == {:ok, []}, do: :timer.hours(24), else: @default_cooldown

    Process.send_after(self(), :import_batch, wait_time)
  end
end
