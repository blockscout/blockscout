defmodule Explorer.Chain.Import.Stage.AddressesBlocks do
  @moduledoc """
  Imports addresses before anything else that references them because an unused address is still valid and recoverable
  if the other stage(s) don't commit.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @impl Stage
  def runners, do: [Runner.Addresses, Runner.Blocks]

  @chunk_size 1000

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {addresses_multis, runner_to_changes_list_without_addresses} =
      Stage.chunk_every(runner_to_changes_list, Runner.Addresses, @chunk_size, options)

    {blocks_multis, result_runner_to_changes_list} =
      Stage.split_multis([Runner.Blocks], runner_to_changes_list_without_addresses, options)

    {addresses_multis ++ blocks_multis, result_runner_to_changes_list}
  end
end
