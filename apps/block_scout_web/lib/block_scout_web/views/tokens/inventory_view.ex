defmodule BlockScoutWeb.Tokens.InventoryView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.Tokens.Instance.OverviewView, only: [media_src: 1, media_type: 1]

  alias BlockScoutWeb.Tokens.OverviewView
end
