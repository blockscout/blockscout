defmodule Explorer.TransactionFormTest do
  use Explorer.DataCase

  alias Explorer.TransactionForm

  describe "build/1" do
    test "that it returns the values we expect" do
      insert(:block, number: 24)
      time = Timex.now |> Timex.shift(hours: -2)
      block = insert(:block, %{
        number: 1,
        gas_used: 99523,
        timestamp: time,
      })
      transaction =
        insert(:transaction)
        |> with_block(block)
        |> with_addresses(%{to: "0xsleepypuppy", from: "0xilovefrogs"})
        |> Repo.preload(:block)
      form = TransactionForm.build(transaction)

      assert(form == Map.merge(transaction, %{
        block_number: 1,
        age: "2 hours ago",
        formatted_timestamp: block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime),
        cumulative_gas_used: "99,523",
        to_address: "0xsleepypuppy",
        from_address: "0xilovefrogs",
        confirmations: 23,
        status: "Success",
      }))
    end

    test "works when there is no block" do
      transaction = insert(:transaction) |> with_addresses(%{to: "0xchadmuska", from: "0xtonyhawk"}) |> Repo.preload(:block)
      form = TransactionForm.build(transaction)

      assert(form == Map.merge(transaction, %{
        block_number: "",
        age: "",
        formatted_timestamp: "",
        cumulative_gas_used: "",
        to_address: "0xchadmuska",
        from_address: "0xtonyhawk",
        confirmations: 0,
        status: "Pending",
      }))
    end
  end
end
