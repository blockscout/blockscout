defmodule BlockScoutWeb.Tokens.OverviewView do
  use BlockScoutWeb, :view

  alias Explorer.{Chain, CustomContractsHelper}
  alias Explorer.Chain.{Address, SmartContract, Token}
  alias Explorer.SmartContract.{Helper, Writer}

  alias BlockScoutWeb.{AccessHelper, CurrencyHelper, LayoutView}

  import BlockScoutWeb.AddressView, only: [from_address_hash: 1, contract_interaction_disabled?: 0]

  @tabs ["token-transfers", "token-holders", "read-contract", "inventory"]

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def token_name?(%Token{name: nil}), do: false
  def token_name?(%Token{name: _}), do: true

  def total_supply?(%Token{total_supply: nil}), do: false
  def total_supply?(%Token{total_supply: _}), do: true

  @doc """
  Get the current tab name/title from the request path and possible tab names.

  The tabs on mobile are represented by a dropdown list, which has a title. This title is the
  currently selected tab name. This function returns that name, properly gettext'ed.

  The list of possible tab names for this page is represented by the attribute @tab.

  Raises error if there is no match, so a developer of a new tab must include it in the list.
  """
  def current_tab_name(request_path) do
    @tabs
    |> Enum.filter(&tab_active?(&1, request_path))
    |> tab_name()
  end

  defp tab_name(["token-transfers"]), do: gettext("Token Transfers")
  defp tab_name(["token-holders"]), do: gettext("Token Holders")
  defp tab_name(["read-contract"]), do: gettext("Read Contract")
  defp tab_name(["inventory"]), do: gettext("Inventory")

  def display_inventory?(%Token{type: "ERC-721"}), do: true
  def display_inventory?(%Token{type: "ERC-1155"}), do: true
  def display_inventory?(_), do: false

  def smart_contract_with_read_only_functions?(
        %Token{contract_address: %Address{smart_contract: %SmartContract{}}} = token
      ) do
    Enum.any?(token.contract_address.smart_contract.abi || [], &Helper.queriable_method?(&1))
  end

  def smart_contract_with_read_only_functions?(%Token{contract_address: %Address{smart_contract: nil}}), do: false

  def smart_contract_is_proxy?(%Token{contract_address: %Address{smart_contract: %SmartContract{} = smart_contract}}) do
    SmartContract.proxy_contract?(smart_contract)
  end

  def smart_contract_is_proxy?(%Token{contract_address: %Address{smart_contract: nil}}), do: false

  def smart_contract_with_write_functions?(%Token{
        contract_address: %Address{smart_contract: %SmartContract{}} = address
      }) do
    !contract_interaction_disabled?() &&
      Enum.any?(
        address.smart_contract.abi || [],
        &Writer.write_function?(&1)
      )
  end

  def smart_contract_with_write_functions?(%Token{contract_address: %Address{smart_contract: nil}}), do: false

  @doc """
  Get the total value of the token supply in USD.
  """
  def total_supply_usd(token) do
    if Map.has_key?(token, :custom_cap) && token.custom_cap do
      token.custom_cap
    else
      tokens = CurrencyHelper.divide_decimals(token.total_supply, token.decimals)
      price = token.fiat_value
      Decimal.mult(tokens, price)
    end
  end
end
