defmodule BlockScoutWeb.API.V2.TokenTransferViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.TokenTransferView
  alias Explorer.Chain.TokenTransfer

  describe "prepare_token_transfer_total/1" do
    test "returns value and decimals for ERC-20 transfer" do
      token = build(:token, type: "ERC-20", decimals: 18)

      token_transfer = %TokenTransfer{
        token: token,
        token_type: "ERC-20",
        amount: Decimal.new(1000),
        amounts: nil,
        token_ids: nil,
        token_instance: nil
      }

      result = TokenTransferView.prepare_token_transfer_total(token_transfer)

      assert Decimal.equal?(result["value"], Decimal.new(1000))
      assert result["decimals"] == 18
    end

    test "returns token_id for ERC-721 transfer" do
      token = build(:token, type: "ERC-721")

      token_transfer = %TokenTransfer{
        token: token,
        token_type: "ERC-721",
        amount: nil,
        amounts: nil,
        token_ids: [42],
        token_instance: nil
      }

      result = TokenTransferView.prepare_token_transfer_total(token_transfer)

      assert result["token_id"] == 42
      assert Map.has_key?(result, "token_instance")
    end

    test "returns token_id, value and decimals for ERC-1155 transfer" do
      token = build(:token, type: "ERC-1155", decimals: 0)

      token_transfer = %TokenTransfer{
        token: token,
        token_type: "ERC-1155",
        amount: Decimal.new(5),
        amounts: nil,
        token_ids: [99],
        token_instance: nil
      }

      result = TokenTransferView.prepare_token_transfer_total(token_transfer)

      assert result["token_id"] == 99
      assert Decimal.equal?(result["value"], Decimal.new(5))
      assert result["decimals"] == 0
      assert Map.has_key?(result, "token_instance")
    end
  end
end
