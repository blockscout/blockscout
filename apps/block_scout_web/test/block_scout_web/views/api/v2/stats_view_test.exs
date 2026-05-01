defmodule BlockScoutWeb.API.V2.StatsViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.StatsView
  alias Explorer.Chain.Wei

  test "renders hot_smart_contracts.json" do
    contract_address =
      build(:address,
        fetched_coin_balance: %Wei{value: Decimal.new(500)}
      )

    hot_contract = %{
      contract_address: contract_address,
      contract_address_hash: contract_address.hash,
      transactions_count: 12,
      total_gas_used: 34
    }

    result =
      StatsView.render("hot_smart_contracts.json", %{
        hot_smart_contracts: [hot_contract],
        next_page_params: %{"items_count" => 50}
      })

    assert result.next_page_params == %{"items_count" => 50}
    assert [item] = result.items
    assert item.transactions_count == "12"
    assert item.total_gas_used == "34"
    assert Decimal.equal?(item.balance, Decimal.new(500))
    assert is_map(item.contract_address)
  end
end
