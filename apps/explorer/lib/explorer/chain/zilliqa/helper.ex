defmodule Explorer.Chain.Zilliqa.Helper do
  @moduledoc """
  Common helper functions for Zilliqa.
  """

  alias Explorer.Chain.Transaction

  @scilla_transactions_v Decimal.new(0)

  @doc """
  Checks if a transaction is a Scilla transaction.

  Scilla transactions have `v` set to #{@scilla_transactions_v}.
  """
  @spec scilla_transaction?(Transaction.t() | integer()) :: boolean()
  def scilla_transaction?(%Transaction{v: v}), do: scilla_transaction?(v)
  def scilla_transaction?(v), do: v == @scilla_transactions_v
end
