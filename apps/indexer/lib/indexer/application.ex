defmodule Indexer.Application do
  @moduledoc """
  This is the `Application` module for `Indexer`.
  """

  use Application

  alias Indexer.{AddressBalanceFetcher, BlockFetcher, InternalTransactionFetcher, PendingTransactionFetcher}

  @impl Application
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Indexer.TaskSupervisor},
      {AddressBalanceFetcher, name: AddressBalanceFetcher},
      {PendingTransactionFetcher, name: PendingTransactionFetcher},
      {InternalTransactionFetcher, name: InternalTransactionFetcher},
      {BlockFetcher, []}
    ]

    opts = [strategy: :one_for_one, name: Indexer.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
