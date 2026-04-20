defmodule BlockScoutWeb.API.V2.SearchViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.SearchView
  alias Explorer.Chain.Address

  describe "render search_results.json" do
    test "renders search results list and encoded next_page_params" do
      search_result = %{
        type: "token",
        name: "Token",
        symbol: "TKN",
        address_hash: "0x123",
        icon_url: "https://example.com/token.png",
        token_type: "ERC-20",
        verified: true,
        exchange_rate: Decimal.new("1.5"),
        total_supply: Decimal.new("1000"),
        circulating_market_cap: Decimal.new("1500"),
        is_verified_via_admin_panel: false,
        certified: nil,
        priority: 1,
        reputation: "ok",
        is_smart_contract_address: true
      }

      result =
        SearchView.render("search_results.json", %{
          search_results: [search_result],
          next_page_params: %{"q" => "token", "type" => ""}
        })

      assert [item] = result["items"]
      assert item["type"] == "token"
      assert item["name"] == "Token"
      assert item["exchange_rate"] == "1.5"
      assert item["certified"] == false
      assert item["token_url"] =~ "/token/0x123"
      assert item["address_url"] =~ "/address/0x123"

      assert result["next_page_params"] == %{"q" => "token", "type" => nil}
    end

    test "renders redirect payload for successful lookup" do
      address = build(:address)

      result = SearchView.render("search_results.json", %{result: {:ok, address}})

      assert result["redirect"] == true
      assert result["type"] == "address"
      assert result["parameter"] == Address.checksum(address.hash)
    end

    test "renders not found payload" do
      assert SearchView.render("search_results.json", %{result: {:error, :not_found}}) ==
               %{"redirect" => false, "type" => nil, "parameter" => nil}
    end
  end

  describe "prepare_search_result/1" do
    test "renders transaction search result" do
      transaction = build(:transaction)

      result =
        SearchView.prepare_search_result(%{
          type: "transaction",
          transaction_hash: transaction.hash,
          timestamp: ~U[2024-01-01 00:00:00Z],
          priority: 2
        })

      assert result["type"] == "transaction"
      assert result["transaction_hash"] == to_string(transaction.hash)
      assert result["url"] =~ "/tx/"
      assert result["priority"] == 2
    end
  end
end
