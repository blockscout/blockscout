defmodule Explorer.Migrator.SanitizeMissingTokenBalancesTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Migrator.{SanitizeMissingTokenBalances, MigrationStatus}
  alias Explorer.Repo

  describe "Migrate token balances" do
    test "Unset value and value_fetched_at for token balances related to not processed current token balances" do
      Enum.each(0..10, fn _x ->
        token_balance = insert(:token_balance)

        insert(:token_balance,
          address: token_balance.address,
          token_contract_address_hash: token_balance.token_contract_address_hash,
          token_id: token_balance.token_id
        )

        insert(:address_current_token_balance,
          address: token_balance.address,
          token_contract_address_hash: token_balance.token_contract_address_hash,
          token_id: token_balance.token_id,
          value: nil,
          value_fetched_at: nil
        )

        refute is_nil(token_balance.value)
        refute is_nil(token_balance.value_fetched_at)
      end)

      assert MigrationStatus.get_status("sanitize_missing_token_balances") == nil

      SanitizeMissingTokenBalances.start_link([])
      Process.sleep(100)

      TokenBalance
      |> Repo.all()
      |> Enum.group_by(&{&1.address_hash, &1.token_contract_address_hash, &1.token_id})
      |> Enum.each(fn {_, tbs} ->
        assert [%{value: nil, value_fetched_at: nil}, %{value: old_value, value_fetched_at: old_value_fetched_at}] =
                 Enum.sort_by(tbs, & &1.block_number, &>=/2)

        refute is_nil(old_value)
        refute is_nil(old_value_fetched_at)
      end)

      assert Repo.all(CurrentTokenBalance) == []

      assert MigrationStatus.get_status("sanitize_missing_token_balances") == "completed"
    end
  end
end
