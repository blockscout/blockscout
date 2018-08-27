defmodule BlockScoutWeb.AddressTokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.AddressView

  def number_of_transfers(token) do
    ngettext("%{count} transfer", "%{count} transfers", token.number_of_transfers)
  end
end
