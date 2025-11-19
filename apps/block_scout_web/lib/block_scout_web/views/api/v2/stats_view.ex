defmodule BlockScoutWeb.API.V2.StatsView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper

  def render("hot_smart_contracts.json", %{hot_smart_contracts: hot_smart_contracts, next_page_params: next_page_params}) do
    %{
      items: Enum.map(hot_smart_contracts, &prepare_hot_contract/1),
      next_page_params: next_page_params
    }
  end

  defp prepare_hot_contract(hot_contract) do
    balance =
      hot_contract.contract_address.fetched_coin_balance && hot_contract.contract_address.fetched_coin_balance.value

    %{
      contract_address:
        Helper.address_with_info(nil, hot_contract.contract_address, hot_contract.contract_address_hash, false),
      transactions_count: to_string(hot_contract.transactions_count),
      total_gas_used: to_string(hot_contract.total_gas_used),
      balance: balance
    }
  end
end
