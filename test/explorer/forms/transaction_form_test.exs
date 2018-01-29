defmodule Explorer.TransactionFormTest do
  use Explorer.DataCase
  alias Explorer.TransactionForm

  describe "build/1" do
    setup _context do
      insert(:block, %{number: 24})
      date = "Feb-02-2010 10:48:56 AM Etc/UTC"
      block = insert(:block, %{
        number: 1,
        gas_used: 99523,
        timestamp: Timex.parse!(date, "%b-%d-%Y %H:%M:%S %p %Z", :strftime),
      })
      transaction = insert(:transaction, block: block) |> with_addresses(%{to: "0xsleepypuppy", from: "0xilovefrogs"})
      form = TransactionForm.build(transaction)
      {:ok, %{form: form}}
    end

    test "that it has a block number", %{form: form} do
      assert form.block_number == 1
    end

    test "that it returns the block's age" do
      block = insert(:block, %{
        number: 1,
        gas_used: 99523,
        timestamp: Timex.now |> Timex.shift(hours: -2),
      })
      transaction = insert(:transaction, block: block) |> with_addresses(%{to: "0xsiskelnebert", from: "0xleonardmaltin"})
      assert TransactionForm.build(transaction).age == "2 hours ago"
    end

    test "formats the block's timestamp", %{form: form} do
      assert form.formatted_timestamp == "Feb-02-2010 10:48:56 AM Etc/UTC"
    end

    test "that it returns the cumulative gas used for validating the block", %{form: form} do
      assert form.cumulative_gas_used == 99523
    end

    test "that it returns a 'to address'", %{form: form} do
      assert form.to_address == "0xsleepypuppy"
    end

    test "that it returns a 'from address'", %{form: form} do
      assert form.from_address == "0xilovefrogs"
    end

    test "that it returns confirmations", %{form: form} do
      assert form.confirmations == 23
    end
  end

  describe "confirmations/1" do
    test "when there is only one block" do
      block = insert(:block, %{number: 1})
      transaction = insert(:transaction, %{block: block})
      assert TransactionForm.confirmations(transaction) == 0
    end
  end
end
