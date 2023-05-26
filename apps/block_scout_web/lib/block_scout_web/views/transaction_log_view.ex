defmodule BlockScoutWeb.TransactionLogView do
  use BlockScoutWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.Log
  import BlockScoutWeb.AddressView, only: [implementation_name: 1, primary_name: 1]

  def decode(log, transaction) do
    {result, _contracts_acc, _events_acc} = Log.decode(log, transaction, [], false)
    result
  end
end
