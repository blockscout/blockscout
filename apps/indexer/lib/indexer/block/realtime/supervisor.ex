defmodule Indexer.Block.Realtime.Supervisor do
  @moduledoc """
  Supervises realtime block fetcher.
  """

  use Supervisor

  def start_link([arguments, gen_server_options]) do
    Supervisor.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl Supervisor
  def init(%{block_fetcher: block_fetcher, subscribe_named_arguments: subscribe_named_arguments}) do
    children =
      [
        {Task.Supervisor, name: Indexer.Block.Realtime.TaskSupervisor},
        {Indexer.Block.Realtime.Fetcher,
          [
            %{block_fetcher: block_fetcher, subscribe_named_arguments: subscribe_named_arguments},
            [name: Indexer.Block.Realtime.Fetcher]
          ]}
      ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
