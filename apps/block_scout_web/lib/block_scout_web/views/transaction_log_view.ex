defmodule BlockScoutWeb.TransactionLogView do
  use BlockScoutWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.Log
  import BlockScoutWeb.AddressView, only: [implementation_name: 1, primary_name: 1]

  def decode(log, transaction) do
    Log.decode(log, transaction)
  end
end
