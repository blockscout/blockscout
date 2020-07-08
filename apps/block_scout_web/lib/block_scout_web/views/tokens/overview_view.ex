defmodule BlockScoutWeb.Tokens.OverviewView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Address, SmartContract, Token}

  alias BlockScoutWeb.{CurrencyHelpers, LayoutView}

  @tabs ["token_transfers", "token_holders", "read_contract", "inventory"]

  @honey_token "0x71850b7e9ee3f13ab46d67167341e4bdc905eef9"

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

  defp tab_name(["token_transfers"]), do: gettext("Token Transfers")
  defp tab_name(["token_holders"]), do: gettext("Token Holders")
  defp tab_name(["read_contract"]), do: gettext("Read Contract")
  defp tab_name(["inventory"]), do: gettext("Inventory")

  def display_inventory?(%Token{type: "ERC-721"}), do: true
  def display_inventory?(_), do: false

  def smart_contract_with_read_only_functions?(
        %Token{contract_address: %Address{smart_contract: %SmartContract{}}} = token
      ) do
    Enum.any?(token.contract_address.smart_contract.abi, &(&1["constant"] || &1["stateMutability"] == "view"))
  end

  def smart_contract_with_read_only_functions?(%Token{contract_address: %Address{smart_contract: nil}}), do: false

  @doc """
  Get the total value of the token supply in USD.
  """
  def total_supply_usd(token) do
    tokens = CurrencyHelpers.divide_decimals(token.total_supply, token.decimals)
    price = token.usd_value
    Decimal.mult(tokens, price)
  end

  def moon_token?(contract_address) do
    reddit_token?(contract_address, :moon_token_addresses)
  end

  def bricks_token?(contract_address) do
    reddit_token?(contract_address, :bricks_token_addresses)
  end

  def custom_token?(contract_address) do
    contract_address_lower = "0x" <> Base.encode16(contract_address.bytes, case: :lower)

    case contract_address_lower do
      @honey_token -> true
      _ -> false
    end
  end

  def honey_token?(contract_address) do
    contract_address_lower = "0x" <> Base.encode16(contract_address.bytes, case: :lower)

    case contract_address_lower do
      @honey_token -> true
      _ -> false
    end
  end

  def custom_token_icon(contract_address) do
    contract_address_lower = "0x" <> Base.encode16(contract_address.bytes, case: :lower)

    case contract_address_lower do
      _ -> ""
    end
  end

  defp reddit_token?(contract_address, env_var) do
    token_addresses_string = Application.get_env(:block_scout_web, env_var)
    contract_address_lower = Base.encode16(contract_address.bytes, case: :lower)

    if token_addresses_string do
      token_addresses =
        try do
          token_addresses_string
          |> String.downcase()
          |> String.split(",")
        rescue
          _ ->
            []
        end

      token_addresses
      |> Enum.any?(fn token ->
        token == "0x" <> contract_address_lower
      end)
    else
      false
    end
  end
end
