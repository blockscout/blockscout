defmodule BlockScoutWeb.BridgedTokensView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Token

  @owl_token_amb "0x0905Ab807F8FD040255F0cF8fa14756c1D824931"
  @owl_token_omni "0x750eCf8c11867Ce5Dbc556592c5bb1E0C6d16538"

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def token_display_name(%Token{name: nil}), do: ""

  def token_display_name(%Token{name: name}), do: name

  def owl_token_amb?(address_hash) do
    to_string(address_hash) == String.downcase(@owl_token_amb)
  end

  def owl_token_omni?(address_hash) do
    to_string(address_hash) == String.downcase(@owl_token_omni)
  end

  def owl_token_amb_info do
    "<div class='token-bridge-market-cap-header'>Bridged through AMB extension OWL token, which supports <i>burnOwl</i> method.</div>"
  end

  def owl_token_omni_info do
    "<div class='token-bridge-market-cap-header'>Bridged through OmniBridge OWL token. It doesn't support <i>burnOwl</i> method.</div>"
  end
end
