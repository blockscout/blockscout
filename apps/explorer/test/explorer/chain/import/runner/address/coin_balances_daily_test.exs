# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.Address.CoinBalancesDailyTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Address.CoinBalanceDaily
  alias Explorer.Chain.Import.Runner.Address.CoinBalancesDaily
  alias Explorer.Chain.Wei

  @day ~D[2026-11-17]
  @old_timestamp ~U[2026-11-17 00:00:00.000000Z]

  describe "run/3" do
    test "inserts a daily balance" do
      %{hash: address_hash} = insert(:address)

      assert {:ok, %{address_coin_balances_daily: [%{address_hash: ^address_hash, day: @day}]}} =
               run_changes(%{address_hash: address_hash, day: @day, value: wei(100)})

      assert %CoinBalanceDaily{value: value} = Repo.one!(CoinBalanceDaily)
      assert value == wei(100)
    end

    test "updates the row when the incoming value is greater" do
      %{hash: address_hash} = insert(:address)
      insert_daily_balance(address_hash, 100)

      assert {:ok, %{address_coin_balances_daily: [%{address_hash: ^address_hash, day: @day}]}} =
               run_changes(%{address_hash: address_hash, day: @day, value: wei(101)})

      assert %CoinBalanceDaily{value: value, inserted_at: inserted_at, updated_at: updated_at} =
               Repo.one!(CoinBalanceDaily)

      assert value == wei(101)
      assert inserted_at == @old_timestamp
      assert DateTime.compare(updated_at, @old_timestamp) == :gt
    end

    test "leaves the row untouched when the incoming value is equal" do
      %{hash: address_hash} = insert(:address)
      insert_daily_balance(address_hash, 100)
      row_version_before = row_version()

      assert {:ok, %{address_coin_balances_daily: [%{address_hash: ^address_hash, day: @day}]}} =
               run_changes(%{address_hash: address_hash, day: @day, value: wei(100)})

      assert %CoinBalanceDaily{value: value, inserted_at: @old_timestamp, updated_at: @old_timestamp} =
               Repo.one!(CoinBalanceDaily)

      assert value == wei(100)
      assert row_version() == row_version_before
    end

    test "leaves the row untouched when the incoming value is lower" do
      %{hash: address_hash} = insert(:address)
      insert_daily_balance(address_hash, 100)
      row_version_before = row_version()

      assert {:ok, _} = run_changes(%{address_hash: address_hash, day: @day, value: wei(99)})

      assert %CoinBalanceDaily{value: value, inserted_at: @old_timestamp, updated_at: @old_timestamp} =
               Repo.one!(CoinBalanceDaily)

      assert value == wei(100)
      assert row_version() == row_version_before
    end

    test "leaves the row untouched when the incoming value is missing" do
      %{hash: address_hash} = insert(:address)
      insert_daily_balance(address_hash, 100)
      row_version_before = row_version()

      assert {:ok, _} = run_changes(%{address_hash: address_hash, day: @day})

      assert %CoinBalanceDaily{value: value, updated_at: @old_timestamp} = Repo.one!(CoinBalanceDaily)
      assert value == wei(100)
      assert row_version() == row_version_before
    end

    test "fills a NULL stored value" do
      %{hash: address_hash} = insert(:address)
      insert_daily_balance(address_hash, nil)

      assert {:ok, _} = run_changes(%{address_hash: address_hash, day: @day, value: wei(0)})

      assert %CoinBalanceDaily{value: value, inserted_at: inserted_at, updated_at: updated_at} =
               Repo.one!(CoinBalanceDaily)

      assert value == wei(0)
      assert inserted_at == @old_timestamp
      assert DateTime.compare(updated_at, @old_timestamp) == :gt
    end

    test "keeps the greatest value when one batch has several changes for the same address and day" do
      %{hash: address_hash} = insert(:address)

      assert {:ok, %{address_coin_balances_daily: [%{address_hash: ^address_hash, day: @day}]}} =
               run_changes_list([
                 %{address_hash: address_hash, day: @day, value: wei(5)},
                 %{address_hash: address_hash, day: @day, value: wei(7)},
                 %{address_hash: address_hash, day: @day, value: wei(6)}
               ])

      assert %CoinBalanceDaily{value: value} = Repo.one!(CoinBalanceDaily)
      assert value == wei(7)
    end
  end

  defp wei(value), do: %Wei{value: Decimal.new(value)}

  defp insert_daily_balance(address_hash, value) do
    Repo.insert!(%CoinBalanceDaily{
      address_hash: address_hash,
      day: @day,
      value: value && wei(value),
      inserted_at: @old_timestamp,
      updated_at: @old_timestamp
    })
  end

  # `ctid` changes whenever PostgreSQL writes a new version of the row, even if all column values stay the same.
  defp row_version do
    %{rows: [[row_version]]} = Repo.query!("SELECT ctid::text FROM address_coin_balances_daily")
    row_version
  end

  defp run_changes(changes) when is_map(changes), do: run_changes_list([changes])

  defp run_changes_list(changes_list) when is_list(changes_list) do
    timestamp = DateTime.utc_now()

    Multi.new()
    |> CoinBalancesDaily.run(changes_list, %{
      timeout: :infinity,
      timestamps: %{inserted_at: timestamp, updated_at: timestamp}
    })
    |> Repo.transaction()
  end
end
