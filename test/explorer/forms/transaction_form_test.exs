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
      transaction =
        insert(:transaction)
        |> with_block(block)
        |> with_addresses(%{to: "0xsleepypuppy", from: "0xilovefrogs"})

      form = TransactionForm.build(transaction)
      {:ok, %{form: form}}
    end

    test "that it has a block number when it has a block", %{form: form} do
      assert form.block_number == 1
    end

    test "shows a blank block number when the transaction is pending" do
      transaction = insert(:transaction) |> with_addresses
      assert TransactionForm.build(transaction).block_number == ""
    end

    test "that it returns the block's age when has a block" do
      block = insert(:block, %{
        number: 1,
        gas_used: 99523,
        timestamp: Timex.now |> Timex.shift(hours: -2),
      })
      transaction = insert(:transaction) |> with_block(block) |> with_addresses(%{to: "0xsiskelnebert", from: "0xleonardmaltin"})
      assert TransactionForm.build(transaction).age == "2 hours ago"
    end

    test "that it has an empty age when it is pending" do
      transaction = insert(:transaction) |> with_addresses
      assert TransactionForm.build(transaction).age == ""
    end

    test "formats the timestamp when it has a block", %{form: form} do
      assert form.formatted_timestamp == "Feb-02-2010 10:48:56 AM Etc/UTC"
    end

    test "formats the timestamp when the transaction is pending" do
      transaction = insert(:transaction) |> with_addresses
      assert TransactionForm.build(transaction).formatted_timestamp == ""
    end

    test "that it returns the cumulative gas used for validating the block", %{form: form} do
      assert form.cumulative_gas_used == "99,523"
    end

    test "shows the cumulative gas used for a pending transaction" do
      transaction = insert(:transaction) |> with_addresses
      assert TransactionForm.build(transaction).cumulative_gas_used == ""
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

    test "shows confirmations when the transaction is pending" do
      transaction = insert(:transaction) |> with_addresses
      assert TransactionForm.build(transaction).confirmations == 0
    end
  end

  describe "cumulative_gas_used/1" do
    test "when there is a block" do
      block = insert(:block, %{gas_used: 1_000})
      assert TransactionForm.cumulative_gas_used(block) == "1,000"
    end

    test "when there is not a block" do
      assert TransactionForm.cumulative_gas_used(nil) == ""
    end
  end

  describe "confirmations/1" do
    test "when there is only one block" do
      block = insert(:block, %{number: 1})
      insert(:transaction) |> with_block(block) |> with_addresses
      assert TransactionForm.confirmations(block) == 0
    end
  end
end
