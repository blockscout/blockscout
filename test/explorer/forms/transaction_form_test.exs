defmodule Explorer.TransactionFormTest do
  use Explorer.DataCase
  alias Explorer.TransactionForm

  describe "build/1" do
    test "that it has a block number" do
      block = insert(:block, number: 622)
      transaction = insert(:transaction, block: block)
      assert TransactionForm.build(transaction).block_number == 622
    end

    test "that it returns the block's age" do
      block = insert(:block, timestamp: Timex.now |> Timex.shift(hours: -2))
      transaction = insert(:transaction, block: block)
      assert TransactionForm.build(transaction).age == "2 hours ago"
    end

    test "formats the block's timestamp" do
      date = "Feb-02-2010 10:48:56 AM Etc/UTC"
      block = insert(:block, timestamp: Timex.parse!(date, "%b-%d-%Y %H:%M:%S %p %Z", :strftime))
      transaction = insert(:transaction, block: block)
      assert TransactionForm.build(transaction).formatted_timestamp == date
    end

    test "that it returns the cumulative gas used for validating the block" do
      block = insert(:block, number: 622, gas_used: 99523)
      transaction = insert(:transaction, block: block)
      assert TransactionForm.build(transaction).cumulative_gas_used == 99523
    end
  end
end
