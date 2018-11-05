defmodule Explorer.Chain.Supply.TransactionAndLogTest do
  use Explorer.DataCase
  alias Explorer.Chain
  alias Explorer.Chain.Supply.TransactionAndLog

  setup do
    {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")

    burn_address =
      case Chain.hash_to_address(burn_address_hash) do
        {:ok, burn_address} -> burn_address
        {:error, :not_found} -> insert(:address, hash: "0x0000000000000000000000000000000000000000")
      end

    {:ok, %{burn_address: burn_address}}
  end

  describe "total/1" do
    test "today with no mints or burns brings zero" do
      assert TransactionAndLog.total(Timex.now()) == Decimal.new(0)
    end

    test "today with mints and burns calculates a value", %{burn_address: burn_address} do
      old_block = insert(:block, timestamp: Timex.shift(Timex.now(), days: -1), number: 1000)

      insert(:log,
        transaction:
          insert(:transaction, block: old_block, block_number: 1000, cumulative_gas_used: 1, gas_used: 1, index: 2),
        first_topic: "0x3c798bbcf33115b42c728b8504cff11dd58736e9fa789f1cda2738db7d696b2a",
        data: "0x0000000000000000000000000000000000000000000000008ac7230489e80000"
      )

      insert(:internal_transaction,
        index: 527,
        transaction:
          insert(:transaction, block: old_block, block_number: 1000, cumulative_gas_used: 1, gas_used: 1, index: 3),
        to_address: burn_address,
        value: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
      )

      assert TransactionAndLog.total(Timex.now()) == Decimal.new(9)
    end

    test "yesterday with mints and burns calculates a value ignoring whatever happened today", %{
      burn_address: burn_address
    } do
      old_block = insert(:block, timestamp: Timex.shift(Timex.now(), days: -1), number: 1000)

      insert(:log,
        transaction:
          insert(:transaction, block: old_block, block_number: 1000, cumulative_gas_used: 1, gas_used: 1, index: 2),
        first_topic: "0x3c798bbcf33115b42c728b8504cff11dd58736e9fa789f1cda2738db7d696b2a",
        data: "0x0000000000000000000000000000000000000000000000008ac7230489e80000"
      )

      new_block = insert(:block, timestamp: Timex.now(), number: 1001)

      insert(:internal_transaction,
        index: 527,
        transaction:
          insert(:transaction, block: new_block, block_number: 1000, cumulative_gas_used: 1, gas_used: 1, index: 3),
        to_address: burn_address,
        value: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
      )

      assert TransactionAndLog.total(Timex.shift(Timex.now(), days: -1)) == Decimal.new(10)
    end
  end

  describe "total/0" do
    test "calculates the same value as total/1 receiving today's date", %{burn_address: burn_address} do
      old_block = insert(:block, timestamp: Timex.shift(Timex.now(), days: -1), number: 1000)

      insert(:log,
        transaction:
          insert(:transaction, block: old_block, block_number: 1000, cumulative_gas_used: 1, gas_used: 1, index: 2),
        first_topic: "0x3c798bbcf33115b42c728b8504cff11dd58736e9fa789f1cda2738db7d696b2a",
        data: "0x0000000000000000000000000000000000000000000000008ac7230489e80000"
      )

      insert(:internal_transaction,
        index: 527,
        transaction:
          insert(:transaction, block: old_block, block_number: 1000, cumulative_gas_used: 1, gas_used: 1, index: 3),
        to_address: burn_address,
        value: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
      )

      assert TransactionAndLog.total() == TransactionAndLog.total(Timex.now())
    end
  end

  describe "supply_for_days/1" do
    test "bring the supply of today and yesterday when receiving 2", %{burn_address: burn_address} do
      old_block = insert(:block, timestamp: Timex.shift(Timex.now(), days: -1), number: 1000)

      insert(:log,
        transaction:
          insert(:transaction, block: old_block, block_number: 1000, cumulative_gas_used: 1, gas_used: 1, index: 2),
        first_topic: "0x3c798bbcf33115b42c728b8504cff11dd58736e9fa789f1cda2738db7d696b2a",
        data: "0x0000000000000000000000000000000000000000000000008ac7230489e80000"
      )

      new_block = insert(:block, timestamp: Timex.now(), number: 1001)

      insert(:internal_transaction,
        index: 527,
        transaction:
          insert(:transaction, block: new_block, block_number: 1000, cumulative_gas_used: 1, gas_used: 1, index: 3),
        to_address: burn_address,
        value: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
      )

      expected_result = %{
        Timex.shift(Timex.today(), days: -1) => Decimal.new(10),
        Timex.today() => Decimal.new(9)
      }

      assert TransactionAndLog.supply_for_days(2) == {:ok, expected_result}
    end
  end
end
