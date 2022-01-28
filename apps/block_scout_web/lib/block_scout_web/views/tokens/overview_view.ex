defmodule BlockScoutWeb.Tokens.OverviewView do
  use BlockScoutWeb, :view

  alias Explorer.{Chain, CustomContractsHelpers}
  alias Explorer.Chain.{Address, SmartContract, Token}
  alias Explorer.SmartContract.{Helper, Writer}

  alias BlockScoutWeb.{AccessHelpers, CurrencyHelpers, LayoutView}

  import BlockScoutWeb.AddressView, only: [from_address_hash: 1, is_test?: 1]

  @tabs ["token-transfers", "token-holders", "read-contract", "inventory"]
  @etherscan_token_link "https://etherscan.io/token/"
  @blockscout_base_link "https://blockscout.com/"

  @honey_token "0x71850b7e9ee3f13ab46d67167341e4bdc905eef9"

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def token_name?(%Token{name: nil}), do: false
  def token_name?(%Token{name: _}), do: true

  def token_display_name(token) do
    if token.bridged do
      Chain.token_display_name_based_on_bridge_destination(token.name, token.foreign_chain_id)
    else
      token.name
    end
  end

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
    Enum.any?(token.contract_address.smart_contract.abi, &Helper.queriable_method?(&1))
  end

  def smart_contract_with_read_only_functions?(%Token{contract_address: %Address{smart_contract: nil}}), do: false

  def smart_contract_is_proxy?(%Token{contract_address: %Address{smart_contract: %SmartContract{}} = address}) do
    Chain.proxy_contract?(address.hash, address.smart_contract.abi)
  end

  def smart_contract_is_proxy?(%Token{contract_address: %Address{smart_contract: nil}}), do: false

  def smart_contract_with_write_functions?(%Token{
        contract_address: %Address{smart_contract: %SmartContract{}} = address
      }) do
    Enum.any?(
      address.smart_contract.abi,
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
      tokens = CurrencyHelpers.divide_decimals(token.total_supply, token.decimals)
      price = token.usd_value
      Decimal.mult(tokens, price)
    end
  end

  def custom_token?(contract_address) do
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

  def foreign_bridged_token_explorer_link(token) do
    chain_id = Map.get(token, :foreign_chain_id)

    base_token_explorer_link = get_base_token_explorer_link(chain_id)

    foreign_token_contract_address_hash_string_no_prefix =
      token.foreign_token_contract_address_hash.bytes
      |> Base.encode16(case: :lower)

    foreign_token_contract_address_hash_string = "0x" <> foreign_token_contract_address_hash_string_no_prefix

    base_token_explorer_link <> foreign_token_contract_address_hash_string
  end

  # credo:disable-for-next-line /Complexity/
  defp get_base_token_explorer_link(chain_id) when not is_nil(chain_id) do
    case Decimal.to_integer(chain_id) do
      181 ->
        @blockscout_base_link <> "poa/qdai/tokens/"

      100 ->
        @blockscout_base_link <> "poa/xdai/tokens/"

      99 ->
        @blockscout_base_link <> "poa/core/tokens/"

      77 ->
        @blockscout_base_link <> "poa/sokol/tokens/"

      42 ->
        "https://kovan.etherscan.io/token/"

      3 ->
        "https://ropsten.etherscan.io/token/"

      4 ->
        "https://rinkeby.etherscan.io/token/"

      5 ->
        "https://goerli.etherscan.io/token/"

      1 ->
        @etherscan_token_link

      56 ->
        "https://bscscan.com/token/"

      _ ->
        @etherscan_token_link
    end
  end

  defp get_base_token_explorer_link(_), do: @etherscan_token_link
end
