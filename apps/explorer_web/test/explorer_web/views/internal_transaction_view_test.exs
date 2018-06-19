defmodule ExplorerWeb.InternalTransactionViewTest do
  use ExplorerWeb.ConnCase, async: true

  alias ExplorerWeb.InternalTransactionView

  describe "create?/1" do
    test "with internal transaction of type create returns true" do
      internal_transaction = build(:internal_transaction_create)

      assert InternalTransactionView.create?(internal_transaction)
    end

    test "with non-create type internal transaction returns false" do
      internal_transaction = build(:internal_transaction)

      refute InternalTransactionView.create?(internal_transaction)
    end
  end
end
