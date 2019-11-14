defmodule Explorer.Chain.Import.Runner.CeloAccountsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.CeloAccounts
  alias Explorer.Chain.CeloAccount

  describe "run/1" do
    test "insert new accounts list" do
      pools =
        [params_for(:celo_account), params_for(:celo_account)]
        |> Enum.map(fn param ->
          changeset = CeloAccount.changeset(%CeloAccount{}, param)
          changeset.changes
        end)

      assert {:ok, %{insert_celo_accounts: list}} = run_changes(pools)
      assert Enum.count(list) == Enum.count(pools)
    end
  end

  defp run_changes(changes) do
    Multi.new()
    |> CeloAccounts.run(changes, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end
end
