defmodule BlockScoutWeb.AddressLogsView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Address
  alias Explorer.SmartContract.Helper, as: SmartContractHelper

  import BlockScoutWeb.AddressView, only: [decode: 2]
end
