defmodule BlockScoutWeb.AddressTokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.{AddressView, ChainView}
  alias Explorer.{Chain, CustomContractsHelper}
  alias Explorer.Chain.{Address, CurrencyHelper, Wei}
end
