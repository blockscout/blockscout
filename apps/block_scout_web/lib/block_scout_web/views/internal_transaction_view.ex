defmodule BlockScoutWeb.InternalTransactionView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.InternalTransaction

  use Gettext, backend: BlockScoutWeb.Gettext

  @doc """
  Returns the formatted string for the type of the internal transaction.

  When the type is `call`, we return the formatted string for the call type.

  Examples:

  iex> BlockScoutWeb.InternalTransactionView.type(%Explorer.Chain.InternalTransaction{type: :reward})
  "Reward"

  iex> BlockScoutWeb.InternalTransactionView.type(%Explorer.Chain.InternalTransaction{type: :call, call_type: :delegatecall})
  "Delegate Call"
  """
  def type(%InternalTransaction{type: :call} = it) do
    case InternalTransaction.call_type(it) do
      :call -> gettext("Call")
      :callcode -> gettext("Call Code")
      :delegatecall -> gettext("Delegate Call")
      :staticcall -> gettext("Static Call")
      :invalid -> gettext("Invalid")
    end
  end

  def type(%InternalTransaction{type: :create}), do: gettext("Create")
  def type(%InternalTransaction{type: :create2}), do: gettext("Create2")
  def type(%InternalTransaction{type: :selfdestruct}), do: gettext("Self-Destruct")
  def type(%InternalTransaction{type: :reward}), do: gettext("Reward")
end
