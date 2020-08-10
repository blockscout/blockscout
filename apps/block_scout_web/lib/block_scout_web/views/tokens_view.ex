defmodule BlockScoutWeb.TokensView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Token

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true
end
