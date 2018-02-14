defmodule Explorer.TransactionFormTest do
  use Explorer.DataCase

  alias Explorer.TransactionForm

  describe "build/1" do
    test "returns a successful transaction when there is a successful receipt" do
      insert(:block, number: 24)
      time = Timex.now |> Timex.shift(hours: -2)
      block = insert(:block, %{
        number: 1,
        gas_used: 99523,
        timestamp: time,
      })
      transaction =
        insert(:transaction,
          inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
          updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"))
        |> with_block(block)
        |> with_addresses(%{to: "0xsleepypuppy", from: "0xilovefrogs"})
      insert(:transaction_receipt, status: 1, transaction: transaction)

      form = transaction |> Repo.preload([:block, :to_address, :from_address, :receipt]) |> TransactionForm.build()
      formatted_timestamp = block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime)

      assert(form == %{
        block_number: 1,
        age: "2 hours ago",
        formatted_age: "2 hours ago (#{formatted_timestamp})",
        formatted_timestamp: formatted_timestamp,
        cumulative_gas_used: "99,523",
        to_address_hash: "0xsleepypuppy",
        from_address_hash: "0xilovefrogs",
        confirmations: 23,
        status: :success,
        formatted_status: "Success",
        first_seen: "48 years ago",
        last_seen: "38 years ago",
      })
    end

    test "returns a failed transaction when there is a failed receipt" do
      insert(:block, number: 24)
      time = Timex.now |> Timex.shift(hours: -2)
      block = insert(:block, %{
        number: 1,
        gas_used: 99523,
        timestamp: time,
      })
      transaction =
        insert(:transaction,
          gas: 155,
          inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
          updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"))
        |> with_block(block)
        |> with_addresses(%{to: "0xsleepypuppy", from: "0xilovefrogs"})
      insert(:transaction_receipt, status: 0, gas_used: 100, transaction: transaction)

      form = transaction |> Repo.preload([:block, :to_address, :from_address, :receipt]) |> TransactionForm.build()
      formatted_timestamp = block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime)

      assert(form == %{
        block_number: 1,
        age: "2 hours ago",
        formatted_age: "2 hours ago (#{formatted_timestamp})",
        formatted_timestamp: formatted_timestamp,
        cumulative_gas_used: "99,523",
        to_address_hash: "0xsleepypuppy",
        from_address_hash: "0xilovefrogs",
        confirmations: 23,
        status: :failure,
        formatted_status: "Failure",
        first_seen: "48 years ago",
        last_seen: "38 years ago",
      })
    end

    test "returns a out of gas transaction when the gas matches the gas used" do
      insert(:block, number: 24)
      time = Timex.now |> Timex.shift(hours: -2)
      block = insert(:block, %{
        number: 1,
        gas_used: 99523,
        timestamp: time,
      })
      transaction =
        insert(:transaction,
          gas: 555,
          inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
          updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"))
        |> with_block(block)
        |> with_addresses(%{to: "0xsleepypuppy", from: "0xilovefrogs"})
      insert(:transaction_receipt, status: 0, gas_used: 555, transaction: transaction)

      form = transaction |> Repo.preload([:block, :to_address, :from_address, :receipt]) |> TransactionForm.build()
      formatted_timestamp = block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime)

      assert(form == %{
        block_number: 1,
        age: "2 hours ago",
        formatted_age: "2 hours ago (#{formatted_timestamp})",
        formatted_timestamp: formatted_timestamp,
        cumulative_gas_used: "99,523",
        to_address_hash: "0xsleepypuppy",
        from_address_hash: "0xilovefrogs",
        confirmations: 23,
        status: :out_of_gas,
        formatted_status: "Out of Gas",
        first_seen: "48 years ago",
        last_seen: "38 years ago",
      })
    end

    test "returns a pending transaction when there is no receipt" do
      insert(:block, number: 24)
      time = Timex.now |> Timex.shift(hours: -2)
      block = insert(:block, %{
        number: 1,
        gas_used: 99523,
        timestamp: time,
      })
      transaction =
        insert(:transaction,
          inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
          updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"))
        |> with_block(block)
        |> with_addresses(%{to: "0xsleepypuppy", from: "0xilovefrogs"})
        |> Repo.preload([:block, :to_address, :from_address, :receipt])
      form = TransactionForm.build(transaction)
      formatted_timestamp = block.timestamp |> Timex.format!("%b-%d-%Y %H:%M:%S %p %Z", :strftime)

      assert(form == %{
        block_number: 1,
        age: "2 hours ago",
        formatted_age: "2 hours ago (#{formatted_timestamp})",
        formatted_timestamp: formatted_timestamp,
        cumulative_gas_used: "99,523",
        to_address_hash: "0xsleepypuppy",
        from_address_hash: "0xilovefrogs",
        confirmations: 23,
        status: :pending,
        formatted_status: "Pending",
        first_seen: "48 years ago",
        last_seen: "38 years ago",
      })
    end

    test "returns a pending transaction when there is no block" do
      transaction = insert(
        :transaction,
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"))
      |> with_addresses(%{to: "0xchadmuska", from: "0xtonyhawk"})
      |> Repo.preload([:to_address, :from_address])
      form = TransactionForm.build(transaction)

      assert(form == %{
        block_number: "",
        age: "Pending",
        formatted_age: "Pending",
        formatted_timestamp: "Pending",
        cumulative_gas_used: "Pending",
        to_address_hash: "0xchadmuska",
        from_address_hash: "0xtonyhawk",
        confirmations: 0,
        status: :pending,
        formatted_status: "Pending",
        first_seen: "48 years ago",
        last_seen: "38 years ago",
      })
    end

    test "works when there are no addresses" do
      transaction = insert(
        :transaction,
        inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
        updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"))
      |> Repo.preload([:block, :to_address, :from_address])
      form = TransactionForm.build(transaction)

      assert(form == %{
        block_number: "",
        age: "Pending",
        formatted_age: "Pending",
        formatted_timestamp: "Pending",
        cumulative_gas_used: "Pending",
        to_address_hash: nil,
        from_address_hash: nil,
        confirmations: 0,
        status: :pending,
        formatted_status: "Pending",
        first_seen: "48 years ago",
        last_seen: "38 years ago",
      })
    end
  end

  describe "build_and_merge/1" do
    test "it returns a merged map of a transaction and its built data" do
      insert(:block, number: 24)
      time = Timex.now |> Timex.shift(hours: -2)
      block = insert(:block, %{
        number: 1,
        gas_used: 99523,
        timestamp: time,
      })
      transaction =
        insert(:transaction,
          hash: "0xkittenpower",
          inserted_at: Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}"),
          updated_at: Timex.parse!("1980-01-01T00:00:18-00:00", "{ISO:Extended}"),
          gas: 555)
        |> with_block(block)
        |> with_addresses(%{to: "0xsleepypuppy", from: "0xilovefrogs"})
      insert(:transaction_receipt, status: 0, gas_used: 555, transaction: transaction)

      form = transaction |> Repo.preload([:block, :to_address, :from_address, :receipt]) |> TransactionForm.build_and_merge()

      assert form.hash == "0xkittenpower"
      assert form.block_number == 1
      assert form.formatted_status == "Out of Gas"
    end
  end
end
