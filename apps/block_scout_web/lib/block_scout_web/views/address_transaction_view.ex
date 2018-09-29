defmodule BlockScoutWeb.AddressTransactionView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressView,
    only: [
      contract?: 1,
      smart_contract_verified?: 1,
      smart_contract_with_read_only_functions?: 1,
      has_internal_transactions?: 1,
      has_tokens?: 1
    ]

  def format_current_filter(filter) do
    case filter do
      "to" -> gettext("To")
      "from" -> gettext("From")
      _ -> gettext("All")
    end
  end
end
