defmodule BlockScoutWeb.AddressTokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.{AddressView, ChainView}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Wei}
  alias Explorer.SmartContract.Helper, as: SmartContractHelper
end
