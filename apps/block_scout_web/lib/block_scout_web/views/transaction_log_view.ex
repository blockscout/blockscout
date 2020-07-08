defmodule BlockScoutWeb.TransactionLogView do
  use BlockScoutWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.Log

  def decode(log, transaction, address) do
    Log.decode(log, transaction, address)
  end
end
