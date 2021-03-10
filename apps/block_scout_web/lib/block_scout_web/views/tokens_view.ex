defmodule BlockScoutWeb.TokensView do
  use BlockScoutWeb, :view

  alias Explorer.Chain
  alias Explorer.Chain.{BridgedToken, Token}

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def token_display_name(%Token{name: nil, symbol: nil}, _), do: ""

  def token_display_name(%Token{name: "", symbol: ""}, _), do: ""

  def token_display_name(%Token{name: name, symbol: nil}, _), do: name

  def token_display_name(%Token{name: name, symbol: ""}, _), do: name

  def token_display_name(%Token{name: nil, symbol: symbol}, _), do: symbol

  def token_display_name(%Token{name: "", symbol: symbol}, _), do: symbol

  def token_display_name(%Token{name: name, symbol: symbol, bridged: bridged}, nil) do
    "#{name} (#{symbol})"
  end

  def token_display_name(%Token{name: name, symbol: symbol, bridged: bridged}, %BridgedToken{
        foreign_chain_id: foreign_chain_id
      }) do
    if bridged do
      Chain.token_display_name_based_on_bridge_destination(name, symbol, foreign_chain_id)
    else
      "#{name} (#{symbol})"
    end
  end
end
