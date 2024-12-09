defmodule Explorer.Chain.Zilliqa.Helper do
  @moduledoc """
  Common helper functions for Zilliqa.
  """

  alias Explorer.Chain.Transaction

  @scilla_transactions_type 907_376

  @doc """
  Checks if a transaction is a Scilla transaction.

  Scilla transactions have `type` set to #{@scilla_transactions_type}.
  """
  @spec scilla_transaction?(Transaction.t() | integer()) :: boolean()
  def scilla_transaction?(%Transaction{type: type}), do: scilla_transaction?(type)
  def scilla_transaction?(type), do: type == @scilla_transactions_type
end
