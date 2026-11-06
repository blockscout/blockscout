# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.KnownAssetsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.Cache.KnownAssets

  describe "build_index/1" do
    test "indexes admin-verified and priced tokens by normalized symbol and name" do
      verified = insert(:token, symbol: "USDT", name: "Tether USD", is_verified_via_admin_panel: true)
      priced = insert(:token, symbol: "WETH", name: "Wrapped Ether", fiat_value: Decimal.new("3000"))
      capitalized = insert(:token, symbol: "DAI", name: nil, circulating_market_cap: Decimal.new("1"))

      insert(:token,
        symbol: "SCAM",
        name: "Scam Token",
        is_verified_via_admin_panel: false,
        fiat_value: nil,
        circulating_market_cap: nil
      )

      index = KnownAssets.build_index(%{})

      assert index.symbols["usdt"] == MapSet.new([verified.contract_address_hash])
      assert index.symbols["weth"] == MapSet.new([priced.contract_address_hash])
      assert index.symbols["dai"] == MapSet.new([capitalized.contract_address_hash])
      assert index.names["tetherusd"] == MapSet.new([verified.contract_address_hash])
      assert index.names["wrappedether"] == MapSet.new([priced.contract_address_hash])
      refute Map.has_key?(index.symbols, "scam")
    end

    test "collects every accepted contract of a symbol" do
      first = insert(:token, symbol: "USDC", is_verified_via_admin_panel: true)
      second = insert(:token, symbol: "usdc", is_verified_via_admin_panel: true)

      index = KnownAssets.build_index(%{})

      assert index.symbols["usdc"] == MapSet.new([first.contract_address_hash, second.contract_address_hash])
    end

    test "unions the operator's entries with the database" do
      db_token = insert(:token, symbol: "USDT", is_verified_via_admin_panel: true)
      override_contract = address_hash()
      extra_contract = address_hash()

      index =
        KnownAssets.build_index(%{"usdt" => [override_contract], "extra" => [extra_contract]})

      assert index.symbols["usdt"] == MapSet.new([db_token.contract_address_hash, override_contract])
      assert index.symbols["extra"] == MapSet.new([extra_contract])
      assert index.names["extra"] == MapSet.new([extra_contract])
    end
  end

  describe "index_from_override/1" do
    test "uses the operator's entries for both symbols and names" do
      contract = address_hash()

      assert KnownAssets.index_from_override(%{"usdt" => [contract]}) == %{
               symbols: %{"usdt" => MapSet.new([contract])},
               names: %{"usdt" => MapSet.new([contract])}
             }
    end
  end

  describe "index/0" do
    test "is nil while the cache is not running" do
      assert KnownAssets.index() == nil
    end

    test "holds the index once loaded" do
      token = insert(:token, symbol: "USDT", is_verified_via_admin_panel: true)

      start_supervised!(KnownAssets)
      KnownAssets.reload()

      assert KnownAssets.index().symbols["usdt"] == MapSet.new([token.contract_address_hash])
    end
  end
end
