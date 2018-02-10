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
        gas_limit: 555,
        timestamp: time,
      })
      transaction =
        insert(:transaction,
          inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
          updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"))
        |> with_block(block)
        |> with_addresses(%{to: "0xsleepypuppy", from: "0xilovefrogs"})
        |> Repo.preload([:block, :to_address, :from_address])
      form = TransactionForm.build(transaction)
      formatted_timestamp = block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime)

      assert(form == Map.merge(transaction, %{
        block_number: 1,
        age: "2 hours ago",
        formatted_age: "2 hours ago (#{formatted_timestamp})",
        formatted_timestamp: formatted_timestamp,
        cumulative_gas_used: "99,523",
        to_address_hash: "0xsleepypuppy",
        from_address_hash: "0xilovefrogs",
        confirmations: 23,
        status: "Success",
        first_seen: "48 years ago",
        last_seen: "38 years ago",
        gas_limit: "555",
      }))
    end

    test "works when there is no block" do
      transaction = insert(
        :transaction,
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"))
      |> with_addresses(%{to: "0xchadmuska", from: "0xtonyhawk"}) |> Repo.preload([:block, :to_address, :from_address])
      form = TransactionForm.build(transaction)

      assert(form == Map.merge(transaction, %{
        block_number: "",
        age: "Pending",
        formatted_age: "Pending",
        formatted_timestamp: "Pending",
        cumulative_gas_used: "Pending",
        to_address_hash: "0xchadmuska",
        from_address_hash: "0xtonyhawk",
        confirmations: 0,
        status: "Pending",
        first_seen: "48 years ago",
        last_seen: "38 years ago",
        gas_limit: "Pending",
      }))
    end

    test "works when there are no addresses" do
      transaction = insert(
        :transaction,
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"))
      |> Repo.preload([:block, :to_address, :from_address])
      form = TransactionForm.build(transaction)

      assert(form == Map.merge(transaction, %{
        block_number: "",
        age: "Pending",
        formatted_age: "Pending",
        formatted_timestamp: "Pending",
        cumulative_gas_used: "Pending",
        gas_limit: "Pending",
        to_address_hash: nil,
        from_address_hash: nil,
        confirmations: 0,
        status: "Pending",
        first_seen: "48 years ago",
        last_seen: "38 years ago",
      }))
    end
  end
end
