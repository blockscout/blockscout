defmodule BlockScoutWeb.TransactionLogView do
  use BlockScoutWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  import BlockScoutWeb.AddressView, only: [decode: 2, primary_name: 1]
end
