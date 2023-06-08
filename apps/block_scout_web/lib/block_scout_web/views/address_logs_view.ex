defmodule BlockScoutWeb.AddressLogsView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Address

  import BlockScoutWeb.AddressView, only: [decode: 2]
end
