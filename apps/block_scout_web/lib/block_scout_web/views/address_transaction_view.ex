defmodule BlockScoutWeb.AddressTransactionView do
  use BlockScoutWeb, :view

  def format_current_filter(filter) do
    case filter do
      "to" -> gettext("To")
      "from" -> gettext("From")
      _ -> gettext("All")
    end
  end
end
