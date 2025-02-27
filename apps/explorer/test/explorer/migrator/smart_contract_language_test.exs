defmodule Explorer.Migrator.SmartContractLanguageTest do
  use Explorer.DataCase, async: false

  alias Explorer.Migrator.{MigrationStatus, SmartContractLanguage}
  alias Explorer.Chain.{Cache.BackgroundMigrations, SmartContract}
  alias Explorer.Repo

  defp create_contracts(attrs) do
    for _ <- 1..10, do: insert(:smart_contract, attrs)
  end

  describe "smart_contract_language migration" do
    test "backfills language for vyper, yul, solidity" do
      # Create groups of contracts with different attributes
      vyper_contracts =
        create_contracts(is_vyper_contract: true, language: nil)

      yul_contracts =
        create_contracts(is_vyper_contract: false, abi: nil, language: nil)

      solidity_contracts =
        create_contracts(is_vyper_contract: false, language: nil)

      # Ensure migration has not run yet
      assert MigrationStatus.get_status("smart_contract_language") == nil

      # Start the migration process and wait briefly for it to complete
      SmartContractLanguage.start_link([])
      Process.sleep(200)

      # Confirm that the contracts have been updated with the correct language
      [
        {vyper_contracts, :vyper},
        {yul_contracts, :yul},
        {solidity_contracts, :solidity}
      ]
      |> Enum.each(fn {contracts, expected_language} ->
        updated =
          SmartContract
          |> where([sc], sc.address_hash in ^Enum.map(contracts, & &1.address_hash))
          |> Repo.all()

        assert Enum.all?(updated, &(&1.language == expected_language))
      end)

      # Confirm the migration status has been marked as completed
      assert MigrationStatus.get_status("smart_contract_language") == "completed"
      assert BackgroundMigrations.get_smart_contract_language_finished()
    end
  end
end
