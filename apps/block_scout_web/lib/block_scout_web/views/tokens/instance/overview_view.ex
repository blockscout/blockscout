defmodule BlockScoutWeb.Tokens.Instance.OverviewView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.CurrencyHelpers
  alias Explorer.Chain.{Address, SmartContract, Token}

  import BlockScoutWeb.APIDocsView, only: [blockscout_url: 1]

  @tabs ["token_transfers", "metadata"]

  def token_name?(%Token{name: nil}), do: false
  def token_name?(%Token{name: _}), do: true

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def total_supply?(%Token{total_supply: nil}), do: false
  def total_supply?(%Token{total_supply: _}), do: true

  def image_src(nil), do: "/images/controller.svg"

  def image_src(instance) do
    result =
      cond do
        instance.metadata && instance.metadata["image_url"] ->
          instance.metadata["image_url"]

        instance.metadata && instance.metadata["image"] ->
          instance.metadata["image"]

        instance.metadata && instance.metadata["properties"]["image"]["description"] ->
          instance.metadata["properties"]["image"]["description"]

        true ->
          image_src(nil)
      end

    if String.trim(result) == "", do: image_src(nil), else: result
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

    is_api = false
    url = Path.join(blockscout_url(is_api), token_instance_path)

    url
    |> QRCode.to_png()
    |> Base.encode64()
  end

  def current_tab_name(request_path) do
    @tabs
    |> Enum.filter(&tab_active?(&1, request_path))
    |> tab_name()
  end

  defp tab_name(["token_transfers"]), do: gettext("Token Transfers")
  defp tab_name(["metadata"]), do: gettext("Metadata")
end
