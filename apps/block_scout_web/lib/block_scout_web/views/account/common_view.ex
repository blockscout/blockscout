defmodule BlockScoutWeb.Account.CommonView do
  use BlockScoutWeb, :view

  def nav_class(active_item, item) do
    if active_item == item do
      "dropdown-item active fs-14"
    else
      "dropdown-item fs-14"
    end
  end
end
