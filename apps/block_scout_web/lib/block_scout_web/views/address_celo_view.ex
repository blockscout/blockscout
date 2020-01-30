defmodule BlockScoutWeb.AddressCeloView do
  use BlockScoutWeb, :view
  
  def list_with_items?(lst) do
    lst != nil and Ecto.assoc_loaded?(lst) and Enum.count(lst) > 0
  end
end
