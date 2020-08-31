defmodule BlockScoutWeb.BridgedTokensView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Token

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def token_display_name(%Token{name: nil}), do: ""

  def token_display_name(%Token{name: name}), do: name
end
