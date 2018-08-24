defmodule Indexer.BlockFetcher.Supervisor do
  @moduledoc """
  Supervises catchup and realtime block fetchers
  """

  alias Indexer.BlockFetcher
  alias Indexer.BlockFetcher.{Catchup, Realtime}

  use Supervisor

  def start_link([arguments, gen_server_options]) do
    Supervisor.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl Supervisor
  def init(%{block_interval: block_interval, subscribe_named_arguments: subscribe_named_arguments} = named_arguments) do
    block_fetcher =
      named_arguments
      |> Map.drop(~w(block_interval subscribe_named_arguments)a)
      |> BlockFetcher.new()

    Supervisor.init(
      [
        {Catchup.Supervisor,
         [%{block_fetcher: block_fetcher, block_interval: block_interval}, [name: Catchup.Supervisor]]},
        {Realtime.Supervisor,
         [
           %{block_fetcher: block_fetcher, subscribe_named_arguments: subscribe_named_arguments},
           [name: Realtime.Supervisor]
         ]}
      ],
      strategy: :one_for_one
    )
  end
end
