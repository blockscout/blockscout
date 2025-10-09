defmodule BlockScoutWeb.AddressInternalTransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.AccessHelper
  alias Explorer.Chain.Address
  alias Explorer.SmartContract.Helper, as: SmartContractHelper

  def format_current_filter(filter) do
    case filter do
      "to" -> gettext("To")
      "from" -> gettext("From")
      _ -> gettext("All")
    end
  end
end
