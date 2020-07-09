defmodule BlockScoutWeb.TransactionLogView do
  use BlockScoutWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.Log

  def decode(log, transaction) do
    Log.decode(log, transaction)
  end
end
