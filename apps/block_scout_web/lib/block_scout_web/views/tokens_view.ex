defmodule BlockScoutWeb.TokensView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Token

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def bridged_tokens_enabled? do
    multi_token_bridge_mediator = Application.get_env(:block_scout_web, :multi_token_bridge_mediator)

    multi_token_bridge_mediator && multi_token_bridge_mediator !== ""
  end
end
