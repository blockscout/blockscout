defmodule BlockScoutWeb.Tokens.HelpersTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.Tokens.Helpers

  describe "token_transfer_amount/1" do
    test "returns the symbol -- with ERC-20 token and amount nil" do
      token = build(:token, type: "ERC-20")
      token_transfer = build(:token_transfer, token: token, amount: nil)

      assert Helpers.token_transfer_amount(token_transfer) == "--"
    end

    test "returns the formatted amount according to token decimals with ERC-20 token" do
      token = build(:token, type: "ERC-20", decimals: 6)
      token_transfer = build(:token_transfer, token: token, amount: Decimal.new(1_000_000))

      assert Helpers.token_transfer_amount(token_transfer) == "1"
    end

    test "returns the formatted amount when the decimals is nil with ERC-20 token" do
      token = build(:token, type: "ERC-20", decimals: nil)
      token_transfer = build(:token_transfer, token: token, amount: Decimal.new(1_000_000))

      assert Helpers.token_transfer_amount(token_transfer) == "1,000,000"
    end

    test "returns a string with the token_id with ERC-721 token" do
      token = build(:token, type: "ERC-721", decimals: nil)
      token_transfer = build(:token_transfer, token: token, amount: nil, token_id: 1)

      assert Helpers.token_transfer_amount(token_transfer) == "TokenID [1]"
    end

    test "returns nothing for unknow token's type" do
      token = build(:token, type: "unknow")
      token_transfer = build(:token_transfer, token: token)

      assert Helpers.token_transfer_amount(token_transfer) == nil
    end
  end

  describe "token_symbol/1" do
    test "returns the token symbol" do
      token = build(:token, symbol: "BAT")

      assert Helpers.token_symbol(token) == "BAT"
    end

    test "returns the token contract address hash when the symbol is nil" do
      address = build(:address)
      token = build(:token, symbol: nil, contract_address_hash: address.hash)

      address_hash =
        address.hash
        |> Explorer.Chain.Hash.to_string()
        |> String.slice(0..6)

      assert Helpers.token_symbol(token) == "#{address_hash}..."
    end
  end
end
