# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.Address.CoinBalancesTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.Import.Runner.Address.CoinBalances
  alias Explorer.Chain.Wei

  @block_number 100
  @old_timestamp ~U[2026-11-17 00:00:00.000000Z]

  describe "run/3" do
    test "inserts a fetched balance and returns it" do
      %{hash: address_hash} = insert(:address)
      value = wei(100)

      assert {:ok,
              %{address_coin_balances: [%{address_hash: ^address_hash, block_number: @block_number, value: ^value}]}} =
               run_changes(fetched(address_hash, 100))

      assert %CoinBalance{value: ^value} = Repo.one!(CoinBalance)
    end

    test "fills an unfetched balance and returns it" do
      %{hash: address_hash} = insert(:address)
      insert_coin_balance(address_hash, nil)
      value = wei(100)

      assert {:ok, %{address_coin_balances: [%{address_hash: ^address_hash, value: ^value}]}} =
               run_changes(fetched(address_hash, 100))

      assert %CoinBalance{value: ^value, value_fetched_at: value_fetched_at} = Repo.one!(CoinBalance)
      refute is_nil(value_fetched_at)
    end

    test "replaces a fetched balance with a different value fetched later and returns it" do
      %{hash: address_hash} = insert(:address)
      insert_coin_balance(address_hash, 100)
      value = wei(101)

      assert {:ok, %{address_coin_balances: [%{address_hash: ^address_hash, value: ^value}]}} =
               run_changes(fetched(address_hash, 101))

      assert %CoinBalance{value: ^value, inserted_at: @old_timestamp} = Repo.one!(CoinBalance)
    end

    test "moves value_fetched_at forward but does not return a balance fetched again with the same value" do
      %{hash: address_hash} = insert(:address)
      insert_coin_balance(address_hash, 100)
      %{value_fetched_at: confirmed_at} = changes = fetched(address_hash, 100)

      assert {:ok, %{address_coin_balances: []}} = run_changes(changes)

      assert %CoinBalance{value: value, value_fetched_at: ^confirmed_at, inserted_at: @old_timestamp} =
               Repo.one!(CoinBalance)

      assert value == wei(100)
    end

    test "rejects a different value fetched before a later confirmation of the stored one" do
      %{hash: address_hash} = insert(:address)
      insert_coin_balance(address_hash, 100)
      t2 = DateTime.add(@old_timestamp, 2)
      t3 = DateTime.add(@old_timestamp, 3)

      # the confirmation fetched at t3 is imported first
      assert {:ok, %{address_coin_balances: []}} =
               run_changes(%{fetched(address_hash, 100) | value_fetched_at: t3})

      # the observation fetched at t2 with another value is imported late
      assert {:ok, %{address_coin_balances: []}} =
               run_changes(%{fetched(address_hash, 101) | value_fetched_at: t2})

      assert %CoinBalance{value: value, value_fetched_at: ^t3} = Repo.one!(CoinBalance)
      assert value == wei(100)
    end

    test "neither rewrites nor returns a balance fetched earlier than the stored one" do
      %{hash: address_hash} = insert(:address)
      insert_coin_balance(address_hash, 100)
      row_version_before = row_version()

      assert {:ok, %{address_coin_balances: []}} =
               run_changes(%{fetched(address_hash, 101) | value_fetched_at: DateTime.add(@old_timestamp, -1)})

      assert %CoinBalance{value: value} = Repo.one!(CoinBalance)
      assert value == wei(100)
      assert row_version() == row_version_before
    end

    test "returns an unfetched balance even when the row is already there" do
      %{hash: address_hash} = insert(:address)
      insert_coin_balance(address_hash, 100)
      row_version_before = row_version()

      assert {:ok, %{address_coin_balances: [%{address_hash: ^address_hash, block_number: @block_number}]}} =
               run_changes(%{address_hash: address_hash, block_number: @block_number})

      assert %CoinBalance{value: value} = Repo.one!(CoinBalance)
      assert value == wei(100)
      assert row_version() == row_version_before
    end

    test "returns only the written balances of a batch" do
      %{hash: unchanged_address_hash} = insert(:address)
      %{hash: changed_address_hash} = insert(:address)
      %{hash: new_address_hash} = insert(:address)
      insert_coin_balance(unchanged_address_hash, 100)
      insert_coin_balance(changed_address_hash, 100)

      assert {:ok, %{address_coin_balances: imported}} =
               run_changes_list([
                 fetched(unchanged_address_hash, 100),
                 fetched(changed_address_hash, 200),
                 fetched(new_address_hash, 300)
               ])

      assert imported |> Enum.map(& &1.address_hash) |> MapSet.new() ==
               MapSet.new([changed_address_hash, new_address_hash])
    end
  end

  defp wei(value), do: %Wei{value: Decimal.new(value)}

  defp fetched(address_hash, value) do
    %{address_hash: address_hash, block_number: @block_number, value: wei(value), value_fetched_at: DateTime.utc_now()}
  end

  defp insert_coin_balance(address_hash, value) do
    Repo.insert!(%CoinBalance{
      address_hash: address_hash,
      block_number: @block_number,
      value: value && wei(value),
      value_fetched_at: value && @old_timestamp,
      inserted_at: @old_timestamp,
      updated_at: @old_timestamp
    })
  end

  # `ctid` changes whenever PostgreSQL writes a new version of the row, even if all column values stay the same.
  defp row_version do
    %{rows: [[row_version]]} = Repo.query!("SELECT ctid::text FROM address_coin_balances")
    row_version
  end

  defp run_changes(changes) when is_map(changes), do: run_changes_list([changes])

  defp run_changes_list(changes_list) when is_list(changes_list) do
    timestamp = DateTime.utc_now()

    Multi.new()
    |> CoinBalances.run(changes_list, %{
      timeout: :infinity,
      timestamps: %{inserted_at: timestamp, updated_at: timestamp}
    })
    |> Repo.transaction()
  end
end
