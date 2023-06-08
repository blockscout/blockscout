defmodule BlockScoutWeb.TransactionLogView do
  use BlockScoutWeb, :view
  @dialyzer :no_match

  import BlockScoutWeb.AddressView, only: [decode: 2, implementation_name: 1, primary_name: 1]
end
