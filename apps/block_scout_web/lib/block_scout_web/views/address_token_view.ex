defmodule BlockScoutWeb.AddressTokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.AddressView

  def number_of_transfers(token) do
    ngettext("%{count} transfer", "%{count} transfers", token.transfers_count)
  end
end
