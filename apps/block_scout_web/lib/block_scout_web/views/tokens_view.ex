defmodule BlockScoutWeb.TokensView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Address, Token}

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def token_display_name(%Token{name: nil, symbol: nil}), do: ""

  def token_display_name(%Token{name: "", symbol: ""}), do: ""

  def token_display_name(%Token{name: name, symbol: nil}), do: name

  def token_display_name(%Token{name: name, symbol: ""}), do: name

  def token_display_name(%Token{name: nil, symbol: symbol}), do: symbol

  def token_display_name(%Token{name: "", symbol: symbol}), do: symbol

  def token_display_name(%Token{name: name, symbol: symbol}), do: "#{name} (#{symbol})"
end
