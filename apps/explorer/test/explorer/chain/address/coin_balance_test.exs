defmodule Explorer.Chain.Address.CoinBalanceTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.{Block, Wei}
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
end
