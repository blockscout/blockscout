defmodule Explorer.Chain.Import.Stage.BlockReferencing do
  @moduledoc """
  Imports any tables that reference `t:Explorer.Chain.Block.t/0` and that were
  imported by `Explorer.Chain.Import.Stage.Addresses` and
  `Explorer.Chain.Import.Stage.AddressReferencing`.
  """

  alias Explorer.Chain.Import.{Runner, Stage}

  @behaviour Stage

  @impl Stage
  def runners,
    do: [
      Runner.Transactions,
      Runner.Tokens,
      Runner.TransactionActions
    ]

  @transactions_chunk_size 50

  @impl Stage
  def multis(runner_to_changes_list, options) do
    {transactions_multis, runner_to_changes_list_without_trans} =
      Stage.chunk_every(runner_to_changes_list, Runner.Transactions, @transactions_chunk_size, options)

    {tokens_multis, result_runner_to_changes_list} =
      Stage.split_multis([Runner.Tokens], runner_to_changes_list_without_trans, options)

    {transactions_multis ++ tokens_multis, result_runner_to_changes_list}
  end
end
