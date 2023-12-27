defmodule Explorer.Migrator.AddressCurrentTokenBalanceTokenTypeTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Migrator.{AddressCurrentTokenBalanceTokenType, MigrationStatus}
  alias Explorer.Repo

  describe "Migrate current token balances" do
    test "Set token_type for not processed current token balances" do
      Enum.each(0..10, fn _x ->
        current_token_balance = insert(:address_current_token_balance, token_type: nil)
        assert %{token_type: nil} = current_token_balance
      end)

      assert MigrationStatus.get_status("ctb_token_type") == nil

      AddressCurrentTokenBalanceTokenType.start_link([])
      Process.sleep(100)

      CurrentTokenBalance
      |> Repo.all()
      |> Repo.preload(:token)
      |> Enum.each(fn ctb ->
        assert %{token_type: token_type, token: %{type: token_type}} = ctb
        assert not is_nil(token_type)
      end)

      assert MigrationStatus.get_status("ctb_token_type") == "completed"
      assert BackgroundMigrations.get_ctb_token_type_finished() == true
    end
  end
end
