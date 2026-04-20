defmodule BlockScoutWeb.API.V2.InternalTransactionViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.InternalTransactionView
  alias Explorer.Chain.{InternalTransaction, Wei}

  describe "prepare_internal_transaction/2" do
    test "returns expected fields for a successful call" do
      from_address = build(:address)
      to_address = build(:address)

      internal_transaction = %InternalTransaction{
        error: nil,
        type: :call,
        call_type: :call,
        transaction_hash: nil,
        transaction_index: 0,
        from_address: from_address,
        from_address_hash: from_address.hash,
        to_address: to_address,
        to_address_hash: to_address.hash,
        created_contract_address: nil,
        created_contract_address_hash: nil,
        value: Wei.zero(),
        block_number: 10,
        block: nil,
        index: 0,
        gas: Decimal.new(21_000)
      }

      result = InternalTransactionView.prepare_internal_transaction(internal_transaction, nil)
      expected_type = InternalTransaction.call_type(internal_transaction) || internal_transaction.type

      assert result["success"] == true
      assert result["error"] == nil
      assert result["type"] == expected_type
      assert result["block_number"] == 10
      assert result["index"] == 0
      assert Decimal.equal?(result["gas_limit"], Decimal.new(21_000))
      assert is_map(result["from"])
      assert is_map(result["to"])
    end

    test "returns success false when error is present" do
      from_address = build(:address)
      to_address = build(:address)

      internal_transaction = %InternalTransaction{
        error: "reverted",
        type: :call,
        call_type: :call,
        transaction_hash: nil,
        transaction_index: 1,
        from_address: from_address,
        from_address_hash: from_address.hash,
        to_address: to_address,
        to_address_hash: to_address.hash,
        created_contract_address: nil,
        created_contract_address_hash: nil,
        value: Wei.zero(),
        block_number: 11,
        block: nil,
        index: 1,
        gas: Decimal.new(22_000)
      }

      result = InternalTransactionView.prepare_internal_transaction(internal_transaction, nil)

      assert result["success"] == false
      assert result["error"] == "reverted"
    end

    test "uses provided block timestamp when block is passed" do
      from_address = build(:address)
      to_address = build(:address)
      block = build(:block)

      internal_transaction = %InternalTransaction{
        error: nil,
        type: :call,
        call_type: :call,
        transaction_hash: nil,
        transaction_index: 2,
        from_address: from_address,
        from_address_hash: from_address.hash,
        to_address: to_address,
        to_address_hash: to_address.hash,
        created_contract_address: nil,
        created_contract_address_hash: nil,
        value: Wei.zero(),
        block_number: 12,
        block: nil,
        index: 2,
        gas: Decimal.new(23_000)
      }

      result = InternalTransactionView.prepare_internal_transaction(internal_transaction, block)

      assert result["timestamp"] == block.timestamp
    end
  end
end
