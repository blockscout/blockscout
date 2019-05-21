defmodule Explorer.Chain.Address.CoinBalanceTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.{Block, Wei}
  alias Explorer.Chain.Address.CoinBalance
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
  end

  describe "balance_value_before/2" do
    test "previous value is nil when there is no previous balance" do
      address = insert(:address)
      block = insert(:block)
      insert(:fetched_balance, address_hash: address.hash, block_number: block.number)

      result =
        address.hash
        |> CoinBalance.balance_value_before(block.number)
        |> Repo.one()

      assert(is_nil(result))
    end

    test "previous value is nil when previous balances are unfetched" do
      address = insert(:address)
      block_a = insert(:block)
      block_b = insert(:block)
      insert(:unfetched_balance, address_hash: address.hash, block_number: block_a.number)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_b.number)

      result =
        address.hash
        |> CoinBalance.balance_value_before(block_b.number)
        |> Repo.one()

      assert(is_nil(result))
    end

    test "finds the previous value when a previous balace is fetched" do
      address = insert(:address)
      block_a = insert(:block)
      block_b = insert(:block)
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block_a.number)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_b.number)

      result =
        address.hash
        |> CoinBalance.balance_value_before(block_b.number)
        |> Repo.one()

      assert(result == Wei.from(Decimal.new(1000), :wei))
    end
  end

  describe "balances_params_between/3" do
    test "finds the params between two block numbers of the fetched balances only" do
      address = insert(:address)
      block_a = insert(:block)
      block_b = insert(:block)
      block_c = insert(:block)
      block_d = insert(:block)
      block_e = insert(:block)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_a.number)
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block_b.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: block_c.number)
      insert(:unfetched_balance, address_hash: address.hash, block_number: block_d.number)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_e.number)

      result =
        address.hash
        |> CoinBalance.balances_params_between(block_a.number, block_e.number)
        |> Repo.all()

      block_number_value = result |> Map.new(&{&1.block_number, &1.value})
      assert(Enum.count(result) == 2)
      assert(block_number_value[block_b.number] == Wei.from(Decimal.new(1000), :wei))
      assert(block_number_value[block_c.number] == Wei.from(Decimal.new(2000), :wei))
      assert(not Enum.member?(block_number_value, block_d.number))
    end
  end

  describe "balance_params_following/2" do
    test "following balance params are nil when there is no following balance" do
      address = insert(:address)
      block = insert(:block)
      insert(:fetched_balance, address_hash: address.hash, block_number: block.number)

      result =
        address.hash
        |> CoinBalance.balance_params_following(block.number)
        |> Repo.one()

      assert(is_nil(result))
    end

    test "following balance params are nil when following balance is unfetched" do
      address = insert(:address)
      block_a = insert(:block)
      block_b = insert(:block)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_a.number)
      insert(:unfetched_balance, address_hash: address.hash, block_number: block_b.number)

      result =
        address.hash
        |> CoinBalance.balance_params_following(block_a.number)
        |> Repo.one()

      assert(is_nil(result))
    end

    test "finds the following balance params when a following balance is fetched" do
      address = insert(:address)
      block_a = insert(:block)
      block_b = insert(:block)
      insert(:fetched_balance, address_hash: address.hash, block_number: block_a.number)
      insert(:fetched_balance, address_hash: address.hash, value: 500, block_number: block_b.number)

      result =
        address.hash
        |> CoinBalance.balance_params_following(block_a.number)
        |> Repo.one()

      assert(not is_nil(result))
      assert(result.value == Wei.from(Decimal.new(500), :wei))
      assert(result.block_number == block_b.number)
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

      value = List.first(result) |> Map.get(:value)

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

      value = List.first(result) |> Map.get(:value)

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

      value = List.first(result) |> Map.get(:value)

      assert(value == Wei.from(Decimal.new(3000), :wei))
    end
  end
end
