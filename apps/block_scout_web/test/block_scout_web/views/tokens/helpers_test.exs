defmodule BlockScoutWeb.Tokens.HelpersTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.Tokens.Helpers

  describe "token_transfer_amount/1" do
    test "returns the symbol -- with ERC-20 token and amount nil" do
      token = build(:token, type: "ERC-20")
      token_transfer = build(:token_transfer, token: token, amount: nil)

      assert Helpers.token_transfer_amount(token_transfer) == {:ok, "--"}
    end

    test "returns the formatted amount according to token decimals with ERC-20 token" do
      token = build(:token, type: "ERC-20", decimals: Decimal.new(6))
      token_transfer = build(:token_transfer, token: token, amount: Decimal.new(1_000_000))

      assert Helpers.token_transfer_amount(token_transfer) == {:ok, "1"}
    end

    test "returns the formatted amount when the decimals is nil with ERC-20 token" do
      token = build(:token, type: "ERC-20", decimals: nil)
      token_transfer = build(:token_transfer, token: token, amount: Decimal.new(1_000_000))

      assert Helpers.token_transfer_amount(token_transfer) == {:ok, "1,000,000"}
    end

    test "returns a string with the token_id with ERC-721 token" do
      token = build(:token, type: "ERC-721", decimals: nil)
      token_transfer = build(:token_transfer, token: token, amount: nil, token_id: 1)

      assert Helpers.token_transfer_amount(token_transfer) == {:ok, :erc721_instance}
    end

    test "returns nothing for unknown token's type" do
      token = build(:token, type: "unknown")
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
      address = build(:address, hash: "de3fa0f9f8d47790ce88c2b2b82ab81f79f2e65f")
      token = build(:token, symbol: nil, contract_address_hash: address.hash)

      assert Helpers.token_symbol(token) == "0xde3fa0-f2e65f"
    end
  end

  describe "token_name/1" do
    test "returns the token name" do
      token = build(:token, name: "Batman")

      assert Helpers.token_name(token) == "Batman"
    end

    test "returns the token contract address hash when the name is nil" do
      address = build(:address, hash: "de3fa0f9f8d47790ce88c2b2b82ab81f79f2e65f")
      token = build(:token, name: nil, contract_address_hash: address.hash)

      assert Helpers.token_name(token) == "0xde3fa0-f2e65f"
    end
  end
end
