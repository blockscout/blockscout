defmodule Indexer.Block.Supervisor do
  @moduledoc """
  Supervises `Indexer.Block.Catchup.Supervisor` and `Indexer.Block.Realtime.Supervisor`.
  """

  alias Indexer.Block
  alias Indexer.Block.{Catchup, InvalidConsensus, Realtime, Reward, Uncle}
  alias Indexer.Temporary.FailedCreatedAddresses

  use Supervisor

  def start_link([arguments, gen_server_options]) do
    Supervisor.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl Supervisor
  def init(
        %{
          block_interval: block_interval,
          json_rpc_named_arguments: json_rpc_named_arguments,
          subscribe_named_arguments: subscribe_named_arguments
        } = named_arguments
      ) do
    block_fetcher =
      named_arguments
      |> Map.drop(~w(block_interval memory_monitor subscribe_named_arguments)a)
      |> Block.Fetcher.new()

    memory_monitor = Map.get(named_arguments, :memory_monitor)

    Supervisor.init(
      [
        {Catchup.Supervisor,
         [
           %{block_fetcher: block_fetcher, block_interval: block_interval, memory_monitor: memory_monitor},
           [name: Catchup.Supervisor]
         ]},
        {InvalidConsensus.Supervisor, [[], [name: InvalidConsensus.Supervisor]]},
        {Realtime.Supervisor,
         [
           %{block_fetcher: block_fetcher, subscribe_named_arguments: subscribe_named_arguments},
           [name: Realtime.Supervisor]
         ]},
        {Uncle.Supervisor, [[block_fetcher: block_fetcher, memory_monitor: memory_monitor], [name: Uncle.Supervisor]]},
        {Reward.Supervisor,
         [
           [json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor],
           [name: Reward.Supervisor]
         ]},
        {FailedCreatedAddresses.Supervisor,
         [
           json_rpc_named_arguments,
           [name: FailedCreatedAddresses.Supervisor]
         ]}
      ],
      strategy: :one_for_one
    )
  end
end
