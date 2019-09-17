defmodule BlockScoutWeb.Tokens.Instance.OverviewView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.CurrencyHelpers
  alias Explorer.Chain.{Address, SmartContract, Token}

  import BlockScoutWeb.APIDocsView, only: [blockscout_url: 0]

  def token_name?(%Token{name: nil}), do: false
  def token_name?(%Token{name: _}), do: true

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def total_supply?(%Token{total_supply: nil}), do: false
  def total_supply?(%Token{total_supply: _}), do: true

  def image_src(nil), do: "/images/ether1_logo.svg"

  def image_src(instance) do
    if instance.metadata && instance.metadata["image"] do
      instance.metadata["image"]
    else
      image_src(nil)
    end
  end

  def total_supply_usd(token) do
    tokens = CurrencyHelpers.divide_decimals(token.total_supply, token.decimals)
    price = token.usd_value
    Decimal.mult(tokens, price)
  end

  def smart_contract_with_read_only_functions?(
        %Token{contract_address: %Address{smart_contract: %SmartContract{}}} = token
      ) do
    Enum.any?(token.contract_address.smart_contract.abi, & &1["constant"])
  end

  def smart_contract_with_read_only_functions?(%Token{contract_address: %Address{smart_contract: nil}}), do: false

  def qr_code(conn, token_id, hash) do
    token_instance_path = token_instance_path(conn, :show, to_string(hash), to_string(token_id))

    url = blockscout_url() <> token_instance_path

    url
    |> QRCode.to_png()
    |> Base.encode64()
  end
end
