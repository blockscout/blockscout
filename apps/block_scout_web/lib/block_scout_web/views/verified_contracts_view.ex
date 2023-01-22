defmodule BlockScoutWeb.VerifiedContractsView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressView, only: [balance: 1]
  import BlockScoutWeb.Tokens.OverviewView, only: [total_supply_usd: 1]
  alias BlockScoutWeb.WebRouter.Helpers

  def format_current_filter(filter) do
    case filter do
      "solidity" -> gettext("Solidity")
      "vyper" -> gettext("Vyper")
      "yul" -> gettext("Yul")
      _ -> gettext("All")
    end
  end
end
