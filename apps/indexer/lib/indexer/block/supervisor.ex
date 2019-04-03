defmodule Indexer.Block.Supervisor do
  @moduledoc """
  Supervises `Indexer.Block.Catchup.Supervisor` and `Indexer.Block.Realtime.Supervisor`.
  """

  alias Indexer.Block
  alias Indexer.Block.{Catchup, Realtime, Reward, Uncle}
  alias Indexer.Temporary.{AddressesWithoutCode, FailedCreatedAddresses}

  use Supervisor

  def start_link([arguments, gen_server_options]) do
    Supervisor.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl Supervisor
  def init(
        %{
          block_interval: block_interval,
          json_rpc_named_arguments: json_rpc_named_arguments,
          subscribe_named_arguments: subscribe_named_arguments,
          realtime_overrides: realtime_overrides
        } = named_arguments
      ) do
    block_fetcher =
      named_arguments
      |> Map.drop(~w(block_interval memory_monitor subscribe_named_arguments realtime_overrides)a)
      |> Block.Fetcher.new()

    fixing_realtime_fetcher = %Block.Fetcher{
      broadcast: false,
      callback_module: Realtime.Fetcher,
      json_rpc_named_arguments: json_rpc_named_arguments
    }

    realtime_block_fetcher =
      named_arguments
      |> Map.drop(~w(block_interval memory_monitor subscribe_named_arguments realtime_overrides)a)
      |> Map.merge(Enum.into(realtime_overrides, %{}))
      |> Block.Fetcher.new()

    realtime_subscribe_named_arguments = realtime_overrides[:subscribe_named_arguments] || subscribe_named_arguments

    memory_monitor = Map.get(named_arguments, :memory_monitor)

    Supervisor.init(
      [
        {Catchup.Supervisor,
         [
           %{block_fetcher: block_fetcher, block_interval: block_interval, memory_monitor: memory_monitor},
           [name: Catchup.Supervisor]
         ]},
        {Realtime.Supervisor,
         [
           %{block_fetcher: realtime_block_fetcher, subscribe_named_arguments: realtime_subscribe_named_arguments},
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
         ]},
        {AddressesWithoutCode.Supervisor,
         [
           fixing_realtime_fetcher,
           [name: AddressesWithoutCode.Supervisor]
         ]}
      ],
      strategy: :one_for_one
    )
  end
end
