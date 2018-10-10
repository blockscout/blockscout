defmodule Indexer.Application do
  @moduledoc """
  This is the `Application` module for `Indexer`.
  """

  use Application

  alias Indexer.{
    Memory,
    Shrinkable
  }

  @impl Application
  def start(_type, _args) do
    children = [
      Memory.Monitor,
      Shrinkable.Supervisor
    ]

    opts = [
      # If the `Memory.Monitor` dies, it needs all the `Shrinkable`s to re-register, so restart them.
      strategy: :rest_for_one,
      name: Indexer.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
