defmodule BlockScoutWeb.Tokens.Instance.MetadataView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.Tokens.Instance.OverviewView

  def format_metadata(nil), do: ""

  def format_metadata(metadata), do: Poison.encode!(metadata, pretty: true)
end
