defmodule Explorer.Migrator.AddressTokenBalanceTokenTypeTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Migrator.{AddressTokenBalanceTokenType, MigrationStatus}
  alias Explorer.Repo

  describe "Migrate token balances" do
    test "Set token_type for not processed token balances" do
      Enum.each(0..10, fn _x ->
        token_balance = insert(:token_balance, token_type: nil)
        assert %{token_type: nil} = token_balance
      end)

      assert MigrationStatus.get_status("tb_token_type") == nil

      AddressTokenBalanceTokenType.start_link([])
      Process.sleep(100)

      TokenBalance
      |> Repo.all()
      |> Repo.preload(:token)
      |> Enum.each(fn tb ->
        assert %{token_type: token_type, token: %{type: token_type}} = tb
        assert not is_nil(token_type)
      end)

      assert MigrationStatus.get_status("tb_token_type") == "completed"
      assert BackgroundMigrations.get_tb_token_type_finished() == true
    end
  end
end
