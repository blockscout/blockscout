defmodule Explorer.Chain.Import.Stage.Addresses do
  @moduledoc """
  Import addresses.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @runners [
    Runner.Addresses
  ]

  @impl Stage
  def runners, do: @runners

  @impl Stage
  def all_runners, do: runners()

  @addresses_chunk_size 50

  @impl Stage
  def multis(runner_to_changes_list, options) do
    Stage.chunk_every(runner_to_changes_list, Runner.Addresses, @addresses_chunk_size, options)
  end
end
