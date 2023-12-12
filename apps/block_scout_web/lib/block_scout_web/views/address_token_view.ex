defmodule BlockScoutWeb.AddressTokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.{AddressView, ChainView}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, CurrencyHelper, Wei}
end
