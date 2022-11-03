defmodule BlockScoutWeb.VerifiedContractsView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressView, only: [balance: 1]
  alias BlockScoutWeb.WebRouter.Helpers

  def format_current_filter(filter) do
    case filter do
      "solidity" -> gettext("Solidity")
      "vyper" -> gettext("Vyper")
      _ -> gettext("All")
    end
  end
end
