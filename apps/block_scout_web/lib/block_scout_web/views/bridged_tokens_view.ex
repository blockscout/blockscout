defmodule BlockScoutWeb.BridgedTokensView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressView, only: [is_test?: 1]

  alias BlockScoutWeb.ChainView
  alias Explorer.Chain
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
    "<div class='custom-tooltip-header'>OWL token bridged through AMB extension with support of <i>burnOWL</i> method. It is recommended to use.</div>"
  end

  def owl_token_omni_info do
    "<div class='custom-tooltip-header'>OWL token bridged through OmniBridge without support of <i>burnOWL</i> method. It is not recommended to use.</div>"
  end
end
