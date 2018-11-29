defmodule Explorer.Chain.Import.Stage.Addresses do
  @moduledoc """
  Imports addresses before anything else that references them because an unused address is still valid and recoverable
  if the other stage(s) don't commit.
  """

  alias Ecto.Multi
  alias Explorer.Chain.Import
  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @impl Stage
  def runners, do: [Runner.Addresses]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {changes_list, unstaged_runner_to_changes_list} = Map.pop(runner_to_changes_list, Runner.Addresses)
    multis = address_changes_list_to_multis(changes_list, options)

    {multis, unstaged_runner_to_changes_list}
  end

  defp address_changes_list_to_multis(nil, _), do: []

  defp address_changes_list_to_multis(changes_list, options) do
    changes_list
    |> Stream.chunk_every(Import.row_limit())
    |> Enum.map(fn changes_chunk ->
      Runner.Addresses.run(Multi.new(), changes_chunk, options)
    end)
  end
end
