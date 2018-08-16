defmodule BlockScoutWeb.Tokens.TokenView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Address, SmartContract, Token}
  alias BlockScoutWeb.Tokens.OverviewView

  def smart_contract_with_read_only_functions?(
        %Token{contract_address: %Address{smart_contract: %SmartContract{}}} = token
      ) do
    Enum.any?(token.contract_address.smart_contract.abi, & &1["constant"])
  end

  def smart_contract_with_read_only_functions?(%Token{contract_address: %Address{smart_contract: nil}}), do: false
end
