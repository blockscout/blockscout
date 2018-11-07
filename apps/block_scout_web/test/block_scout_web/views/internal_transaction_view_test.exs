defmodule BlockScoutWeb.InternalTransactionViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.InternalTransactionView
  alias Explorer.Chain.InternalTransaction

  doctest BlockScoutWeb.InternalTransactionView

  describe "type/1" do
    test "returns the correct string when the type is :call and call type is :call" do
      internal_transaction = %InternalTransaction{type: :call, call_type: :call}

      assert InternalTransactionView.type(internal_transaction) == "Call"
    end

    test "returns the correct string when the type is :call and call type is :delegate_call" do
      internal_transaction = %InternalTransaction{type: :call, call_type: :delegatecall}

      assert InternalTransactionView.type(internal_transaction) == "Delegate Call"
    end

    test "returns the correct string when the type is :create" do
      internal_transaction = %InternalTransaction{type: :create}

      assert InternalTransactionView.type(internal_transaction) == "Create"
    end

    test "returns the correct string when the type is :selfdestruct" do
      internal_transaction = %InternalTransaction{type: :selfdestruct}

      assert InternalTransactionView.type(internal_transaction) == "Self-Destruct"
    end

    test "returns the correct string when the type is :reward" do
      internal_transaction = %InternalTransaction{type: :reward}

      assert InternalTransactionView.type(internal_transaction) == "Reward"
    end
  end
end
