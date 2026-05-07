defmodule BlockScoutWeb.API.V2.WithdrawalViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.WithdrawalView
  alias Explorer.Chain.Withdrawal

  describe "prepare_withdrawal/1" do
    test "returns full map when block and address are loaded" do
      withdrawal = build(:withdrawal)

      result = WithdrawalView.prepare_withdrawal(withdrawal)

      assert result["index"] == withdrawal.index
      assert result["validator_index"] == withdrawal.validator_index
      assert result["block_number"] == withdrawal.block.number
      assert is_map(result["receiver"])
      assert result["amount"] == withdrawal.amount
      assert result["timestamp"] == withdrawal.block.timestamp
    end

    test "returns map without block fields when block is not loaded" do
      address = build(:address)

      withdrawal = %Withdrawal{
        index: 1,
        validator_index: 2,
        amount: 100,
        block: %Ecto.Association.NotLoaded{},
        address: address,
        address_hash: address.hash
      }

      result = WithdrawalView.prepare_withdrawal(withdrawal)

      assert result["index"] == 1
      assert result["validator_index"] == 2
      assert is_map(result["receiver"])
      refute Map.has_key?(result, "block_number")
      refute Map.has_key?(result, "timestamp")
    end

    test "returns map without receiver when address is not loaded" do
      block = build(:block)
      address = build(:address)

      withdrawal = %Withdrawal{
        index: 3,
        validator_index: 4,
        amount: 200,
        block: block,
        block_hash: block.hash,
        address: %Ecto.Association.NotLoaded{},
        address_hash: address.hash
      }

      result = WithdrawalView.prepare_withdrawal(withdrawal)

      assert result["index"] == 3
      assert result["validator_index"] == 4
      assert result["block_number"] == block.number
      assert result["timestamp"] == block.timestamp
      refute Map.has_key?(result, "receiver")
    end
  end
end
