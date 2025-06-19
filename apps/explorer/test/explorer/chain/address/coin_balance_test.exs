defmodule Explorer.Chain.Address.CoinBalanceTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.{Address, Block, Wei}
  alias Explorer.PagingOptions

  describe "changeset/2" do
    test "is valid with address_hash, block_number, and value" do
      params = params_for(:fetched_balance)

      assert %Changeset{valid?: true} = CoinBalance.changeset(%CoinBalance{}, params)
    end

    test "address_hash and block_number is required" do
      assert %Changeset{valid?: false, errors: errors} = CoinBalance.changeset(%CoinBalance{}, %{})

      assert is_list(errors)
      assert length(errors) == 2
      assert Keyword.get_values(errors, :address_hash) == [{"can't be blank", [validation: :required]}]
      assert Keyword.get_values(errors, :block_number) == [{"can't be blank", [validation: :required]}]
    end
  end

  describe "fetch_coin_balances/2" do
    test "returns the coin balances for the given address" do
      address_a = insert(:address)
      address_b = insert(:address)

      block_a = insert(:block)
      block_b = insert(:block)
      insert(:fetched_balance, address_hash: address_a.hash, block_number: block_a.number)
      insert(:fetched_balance, address_hash: address_b.hash, block_number: block_b.number)

      result =
        address_a.hash
        |> CoinBalance.fetch_coin_balances(%PagingOptions{page_size: 50})
        |> Repo.all()

      assert(length(result) == 1, "Should return 1 coin balance")

      result_address = List.first(result)
      assert(result_address.address_hash == address_a.hash)
    end

    test "ignores unfetched balances" do
      address = insert(:address)
      block_a = insert(:block)
      block_b = insert(:block)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_a.number)
      insert(:unfetched_balance, address_hash: address.hash, block_number: block_b.number)

      result =
        address.hash
        |> CoinBalance.fetch_coin_balances(%PagingOptions{page_size: 50})
        |> Repo.all()

      assert(length(result) == 1, "Should return 1 coin balance")
    end

    test "sorts the result by block number" do
      address = insert(:address)
      block_a = insert(:block)
      block_b = insert(:block)
      block_c = insert(:block)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_c.number)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_a.number)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_b.number)

      result =
        address.hash
        |> CoinBalance.fetch_coin_balances(%PagingOptions{page_size: 50})
        |> Repo.all()

      assert(length(result) == 3, "Should return 3 coin balance")

      block_numbers = result |> Enum.map(fn cb -> cb.block_number end)
      assert(block_numbers == [block_c.number, block_b.number, block_a.number], "Should sort the results")
    end

    test "limits the result by the given page size" do
      address = insert(:address)
      blocks = insert_list(11, :block)

      Enum.each(blocks, fn block ->
        insert(:fetched_balance, address_hash: address.hash, block_number: block.number)
      end)

      result =
        address.hash
        |> CoinBalance.fetch_coin_balances(%PagingOptions{page_size: 10})
        |> Repo.all()

      assert(length(result) == 10, "Should return 10 coin balances")
    end

    test "includes the delta between successive blocks" do
      address = insert(:address)
      block_a = insert(:block)
      block_b = insert(:block)
      block_c = insert(:block)
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block_a.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2200, block_number: block_b.number)
      insert(:fetched_balance, address_hash: address.hash, value: 1500, block_number: block_c.number)

      result =
        address.hash
        |> CoinBalance.fetch_coin_balances(%PagingOptions{page_size: 50})
        |> Repo.all()

      deltas = result |> Enum.map(fn cb -> cb.delta end)
      expected_deltas = [-700, 1200, 1000] |> Enum.map(&Decimal.new(&1))
      assert(deltas == expected_deltas)
    end

    test "includes delta even when paginating" do
      address = insert(:address)

      values = [1000, 2200, 1500, 2000, 2800, 2500, 3100]

      Enum.each(values, fn value ->
        insert(:fetched_balance, address_hash: address.hash, value: value, block_number: insert(:block).number)
      end)

      result =
        address.hash
        |> CoinBalance.fetch_coin_balances(%PagingOptions{page_size: 5})
        |> Repo.all()

      deltas = result |> Enum.map(fn cb -> cb.delta end)
      expected_deltas = [600, -300, 800, 500, -700] |> Enum.map(&Decimal.new(&1))
      assert(deltas == expected_deltas)
    end
  end

  describe "balances_by_day/1" do
    test "returns one row per day" do
      address = insert(:address)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = insert(:block, timestamp: noon)
      block_one_day_ago = insert(:block, timestamp: Timex.shift(noon, days: -1))
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: block_one_day_ago.number)

      result =
        address.hash
        |> CoinBalance.balances_by_day()
        |> Repo.all()

      assert(length(result) == 2)

      values = Enum.map(result, fn cb -> cb.value end)
      expected_values = Enum.map([2000, 1000], fn x -> Wei.from(Decimal.new(x), :wei) end)
      assert(values == expected_values)
    end

    test "returns only balances for the given address" do
      address_a = insert(:address)
      address_b = insert(:address)

      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = insert(:block, timestamp: noon)
      block_one_day_ago = insert(:block, timestamp: Timex.shift(noon, days: -1))

      insert(:fetched_balance, address_hash: address_a.hash, value: 1000, block_number: block.number)
      insert(:fetched_balance, address_hash: address_a.hash, value: 2000, block_number: block_one_day_ago.number)
      insert(:fetched_balance, address_hash: address_b.hash, value: 3000, block_number: block.number)
      insert(:fetched_balance, address_hash: address_b.hash, value: 4000, block_number: block_one_day_ago.number)

      result =
        address_a.hash
        |> CoinBalance.balances_by_day()
        |> Repo.all()

      assert(length(result) == 2)

      values = Enum.map(result, fn cb -> cb.value end)
      expected_values = Enum.map([2000, 1000], fn x -> Wei.from(Decimal.new(x), :wei) end)
      assert(values == expected_values)
    end

    test "returns dates at midnight" do
      address = insert(:address)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = %Block{timestamp: noon_with_usec} = insert(:block, timestamp: noon)
      block_one_day_ago = insert(:block, timestamp: Timex.shift(noon, days: -1))
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: block_one_day_ago.number)

      result =
        address.hash
        |> CoinBalance.balances_by_day()
        |> Repo.all()

      assert(length(result) == 2)

      dates = Enum.map(result, & &1.date)

      today = Timex.beginning_of_day(noon_with_usec)
      yesterday = today |> Timex.shift(days: -1)
      expected_dates = Enum.map([yesterday, today], &DateTime.to_date/1)

      dates
      |> Stream.zip(expected_dates)
      |> Enum.each(fn {date, expected_date} ->
        assert Date.compare(date, expected_date) == :eq
      end)
    end

    test "gets the max value of the day (value is at the beginning)" do
      address = insert(:address)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = insert(:block, timestamp: noon)
      block_one_hour_ago = insert(:block, timestamp: Timex.shift(noon, hours: -1))
      block_two_hours_ago = insert(:block, timestamp: Timex.shift(noon, hours: -2))
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: block_one_hour_ago.number)
      insert(:fetched_balance, address_hash: address.hash, value: 3000, block_number: block_two_hours_ago.number)

      result =
        address.hash
        |> CoinBalance.balances_by_day()
        |> Repo.all()

      assert(length(result) == 1)

      value = result |> List.first() |> Map.get(:value)

      assert(value == Wei.from(Decimal.new(3000), :wei))
    end

    test "gets the max value of the day (value is at the middle)" do
      address = insert(:address)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = insert(:block, timestamp: noon)
      block_one_hour_ago = insert(:block, timestamp: Timex.shift(noon, hours: -1))
      block_two_hours_ago = insert(:block, timestamp: Timex.shift(noon, hours: -2))
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block.number)
      insert(:fetched_balance, address_hash: address.hash, value: 3000, block_number: block_one_hour_ago.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: block_two_hours_ago.number)

      result =
        address.hash
        |> CoinBalance.balances_by_day()
        |> Repo.all()

      assert(length(result) == 1)

      value = result |> List.first() |> Map.get(:value)

      assert(value == Wei.from(Decimal.new(3000), :wei))
    end

    test "gets the max value of the day (value is at the end)" do
      address = insert(:address)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = insert(:block, timestamp: noon)
      block_one_hour_ago = insert(:block, timestamp: Timex.shift(noon, hours: -1))
      block_two_hours_ago = insert(:block, timestamp: Timex.shift(noon, hours: -2))
      insert(:fetched_balance, address_hash: address.hash, value: 3000, block_number: block.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: block_one_hour_ago.number)
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block_two_hours_ago.number)

      result =
        address.hash
        |> CoinBalance.balances_by_day()
        |> Repo.all()

      assert(length(result) == 1)

      value = result |> List.first() |> Map.get(:value)

      assert(value == Wei.from(Decimal.new(3000), :wei))
    end

    test "fetches old records" do
      address = insert(:address)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)

      old_block = insert(:block, timestamp: Timex.shift(noon, days: -700))
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: old_block.number)

      latest_block_timestamp =
        address.hash
        |> CoinBalance.last_coin_balance_timestamp()
        |> Repo.one()

      result =
        address.hash
        |> CoinBalance.balances_by_day(latest_block_timestamp)
        |> Repo.all()

      assert(length(result) == 1)

      value = result |> List.first() |> Map.get(:value)

      assert(value == Wei.from(Decimal.new(2000), :wei))
    end
  end

  describe "stream_unfetched_balances/2" do
    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Block.t/0` `miner_hash`" do
      %Address{hash: miner_hash} = miner = insert(:address)
      %Block{number: block_number} = insert(:block, miner: miner)
      balance = insert(:unfetched_balance, address_hash: miner_hash, block_number: block_number)

      assert {:ok, [%{address_hash: ^miner_hash, block_number: ^block_number}]} =
               CoinBalance.stream_unfetched_balances([], &[&1 | &2])

      update_balance_value(balance, 1)

      assert {:ok, []} = CoinBalance.stream_unfetched_balances([], &[&1 | &2])
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Transaction.t/0` `from_address_hash`" do
      %Address{hash: from_address_hash} = from_address = insert(:address)
      %Block{number: block_number} = block = insert(:block)

      :transaction
      |> insert(from_address: from_address)
      |> with_block(block)

      balance = insert(:unfetched_balance, address_hash: from_address_hash, block_number: block_number)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: from_address_hash, block_number: block_number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: from_address_hash, block_number: block_number} in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Transaction.t/0` `to_address_hash`" do
      %Address{hash: to_address_hash} = to_address = insert(:address)
      %Block{number: block_number} = block = insert(:block)

      :transaction
      |> insert(to_address: to_address)
      |> with_block(block)

      balance = insert(:unfetched_balance, address_hash: to_address_hash, block_number: block_number)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: to_address_hash, block_number: block_number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: to_address_hash, block_number: block_number} in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Log.t/0` `address_hash`" do
      address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:log, address: address, transaction: transaction, block: block, block_number: block.number)

      balance = insert(:unfetched_balance, address_hash: address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{
               address_hash: address.hash,
               block_number: block.number
             } in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{
               address_hash: address.hash,
               block_number: block.number
             } in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.InternalTransaction.t/0` `created_contract_address_hash`" do
      created_contract_address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        created_contract_address: created_contract_address,
        index: 0,
        transaction: transaction,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      balance = insert(:unfetched_balance, address_hash: created_contract_address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{
               address_hash: created_contract_address.hash,
               block_number: block.number
             } in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{
               address_hash: created_contract_address.hash,
               block_number: block.number
             } in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.InternalTransaction.t/0` `from_address_hash`" do
      from_address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        from_address: from_address,
        index: 0,
        transaction: transaction,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      balance = insert(:unfetched_balance, address_hash: from_address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: from_address.hash, block_number: block.number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: from_address.hash, block_number: block.number} in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.InternalTransaction.t/0` `to_address_hash`" do
      to_address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        to_address: to_address,
        index: 0,
        transaction: transaction,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      balance = insert(:unfetched_balance, address_hash: to_address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: to_address.hash, block_number: block.number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: to_address.hash, block_number: block.number} in balance_fields_list
    end

    test "an address_hash used for multiple block_numbers returns all block_numbers" do
      miner = insert(:address)
      mined_block = insert(:block, miner: miner)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: mined_block.number)

      from_transaction_block = insert(:block)

      :transaction
      |> insert(from_address: miner)
      |> with_block(from_transaction_block)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: from_transaction_block.number)

      to_transaction_block = insert(:block)

      :transaction
      |> insert(to_address: miner)
      |> with_block(to_transaction_block)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: to_transaction_block.number)

      log_block = insert(:block)

      log_transaction =
        :transaction
        |> insert()
        |> with_block(log_block)

      insert(:log, address: miner, transaction: log_transaction, block: log_block, block_number: log_block.number)
      insert(:unfetched_balance, address_hash: miner.hash, block_number: log_block.number)

      from_internal_transaction_block = insert(:block)

      from_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(from_internal_transaction_block)

      insert(
        :internal_transaction_create,
        from_address: miner,
        index: 0,
        transaction: from_internal_transaction_transaction,
        block_number: from_internal_transaction_transaction.block_number,
        block_hash: from_internal_transaction_transaction.block_hash,
        block_index: 0,
        transaction_index: from_internal_transaction_transaction.index
      )

      insert(:unfetched_balance, address_hash: miner.hash, block_number: from_internal_transaction_block.number)

      to_internal_transaction_block = insert(:block)

      to_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(to_internal_transaction_block)

      insert(
        :internal_transaction_create,
        index: 0,
        to_address: miner,
        transaction: to_internal_transaction_transaction,
        block_number: to_internal_transaction_transaction.block_number,
        block_hash: to_internal_transaction_transaction.block_hash,
        block_index: 0,
        transaction_index: to_internal_transaction_transaction.index
      )

      insert(:unfetched_balance, address_hash: miner.hash, block_number: to_internal_transaction_block.number)

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      balance_fields_list_by_address_hash = Enum.group_by(balance_fields_list, & &1.address_hash)

      assert balance_fields_list_by_address_hash[miner.hash] |> Enum.map(& &1.block_number) |> Enum.sort() ==
               Enum.sort([
                 to_internal_transaction_block.number,
                 from_internal_transaction_block.number,
                 log_block.number,
                 to_transaction_block.number,
                 from_transaction_block.number,
                 mined_block.number
               ])
    end

    test "an address_hash used for the same block_number is only returned once" do
      miner = insert(:address)
      block = insert(:block, miner: miner)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: block.number)

      :transaction
      |> insert(from_address: miner)
      |> with_block(block)

      :transaction
      |> insert(to_address: miner)
      |> with_block(block)

      log_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:log, address: miner, transaction: log_transaction, block: block, block_number: block.number)

      from_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        from_address: miner,
        index: 0,
        transaction: from_internal_transaction_transaction,
        block_number: from_internal_transaction_transaction.block_number,
        block_hash: from_internal_transaction_transaction.block_hash,
        block_index: 0,
        transaction_index: from_internal_transaction_transaction.index
      )

      to_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        to_address: miner,
        index: 0,
        transaction: to_internal_transaction_transaction,
        block_number: to_internal_transaction_transaction.block_number,
        block_hash: to_internal_transaction_transaction.block_hash,
        block_index: 1,
        transaction_index: to_internal_transaction_transaction.index
      )

      {:ok, balance_fields_list} =
        CoinBalance.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      balance_fields_list_by_address_hash = Enum.group_by(balance_fields_list, & &1.address_hash)

      assert balance_fields_list_by_address_hash[miner.hash] |> Enum.map(& &1.block_number) |> Enum.sort() == [
               block.number
             ]
    end
  end
end
