defmodule BlockScoutWeb.BridgedTokensView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressView, only: [is_test?: 1]

  alias BlockScoutWeb.ChainView
  alias Explorer.Chain
  alias Explorer.Chain.{Address, BridgedToken, CurrencyHelpers, Token}

  @owl_token_amb "0x0905Ab807F8FD040255F0cF8fa14756c1D824931"
  @owl_token_omni "0x750eCf8c11867Ce5Dbc556592c5bb1E0C6d16538"

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def token_display_name(%Token{name: nil}), do: ""

  def token_display_name(%Token{name: name}), do: name

  def token_display_name(%Token{name: name, bridged: bridged}, %BridgedToken{foreign_chain_id: foreign_chain_id}) do
    if bridged do
      Chain.token_display_name_based_on_bridge_destination(name, foreign_chain_id)
    else
      name
    end
  end

  def type_tag_display_name(type) do
    case type do
      "omni" -> "OMNI"
      "amb" -> "AMB-EXT"
    end
  end

  def type_tag_class_name(type) do
    case type do
      "omni" -> "omni"
      "amb" -> "amb-bridge-mediators"
    end
  end

  def owl_token_amb?(address_hash) do
    to_string(address_hash) == String.downcase(@owl_token_amb)
  end

  def owl_token_omni?(address_hash) do
    to_string(address_hash) == String.downcase(@owl_token_omni)
  end

  def owl_token_amb_info do
    "<div class='custom-tooltip header'>OWL token bridged through AMB extension with support of <i>burnOWL</i> method. It is recommended to use.</div>"
  end

  def owl_token_omni_info do
    "<div class='custom-tooltip header'>OWL token bridged through OmniBridge without support of <i>burnOWL</i> method. It is not recommended to use.</div>"
  end

  @doc """
  Calculates capitalization of the bridged token in USD.
  """
  @spec bridged_token_usd_cap(BridgedToken.t(), Token.t()) :: any()
  def bridged_token_usd_cap(bridged_token, token) do
    if bridged_token.custom_cap do
      bridged_token.custom_cap
    else
      if bridged_token.exchange_rate && token.total_supply do
        Decimal.mult(bridged_token.exchange_rate, CurrencyHelpers.divide_decimals(token.total_supply, token.decimals))
      else
        Decimal.new(0)
      end
    end
  end
end
