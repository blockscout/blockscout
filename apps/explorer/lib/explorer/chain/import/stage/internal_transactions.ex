defmodule Explorer.Chain.Import.Stage.InternalTransactions do
  @moduledoc """
  Imports internal transactions after transactions as internal transactions is unbounded and importing internal
  transactions in a separate stage allows the internal transactions to be chunked independenttly.
  """

  alias Explorer.Chain.Import
  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @runner Runner.InternalTransactions

  @impl Stage
  def runners, do: [@runner]

  @impl Stage
  def multis(runner_to_changes_list, options) do
    Stage.chunk_every(runner_to_changes_list, @runner, Import.row_limit(), options)
  end
end
