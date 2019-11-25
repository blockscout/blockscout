defmodule BlockScoutWeb.Tokens.InventoryView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.Tokens.Instance.OverviewView, only: [image_src: 1]

  alias BlockScoutWeb.Tokens.OverviewView
end
