defmodule BlockScoutWeb.InternalTransactionView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.InternalTransaction

  import BlockScoutWeb.Gettext

  @doc """
  Returns the formatted string for the type of the internal transaction.

  When the type is `call`, we return the formatted string for the call type.

  Examples:

  iex> BlockScoutWeb.InternalTransactionView.type(%Explorer.Chain.InternalTransaction{type: :reward})
  "Reward"

  iex> BlockScoutWeb.InternalTransactionView.type(%Explorer.Chain.InternalTransaction{type: :call, call_type: :delegatecall})
  "Delegate Call"
  """
  def type(%InternalTransaction{type: :call, call_type: call_type}) do
    formatted_type(call_type)
  end

  def type(%InternalTransaction{type: type}) do
    formatted_type(type)
  end

  defp formatted_type(:call), do: gettext("Call")
  defp formatted_type(:delegatecall), do: gettext("Delegate Call")
  defp formatted_type(:create), do: gettext("Create")
  defp formatted_type(:suicide), do: gettext("Suicide")
  defp formatted_type(:reward), do: gettext("Reward")
end
