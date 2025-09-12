defmodule Explorer.Migrator.SanitizeDuplicateSmartContractAdditionalSourcesTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.SmartContractAdditionalSource
  alias Explorer.Migrator.{MigrationStatus, SanitizeDuplicateSmartContractAdditionalSources}
  alias Explorer.Repo

  describe "sanitize duplicates in smart_contracts_additional_sources" do
    test "removes duplicate rows keeping a single record per (address_hash, file_name)" do
      sc1 = insert(:smart_contract)
      sc2 = insert(:smart_contract)

      # for sc1: create duplicates for FileA.sol and a unique FileB.sol
      attrs_a = %{address_hash: sc1.address_hash, file_name: "FileA.sol", contract_source_code: "// A1"}
      attrs_a_dup = %{address_hash: sc1.address_hash, file_name: "FileA.sol", contract_source_code: "// A2"}
      attrs_b = %{address_hash: sc1.address_hash, file_name: "FileB.sol", contract_source_code: "// B"}

      %SmartContractAdditionalSource{} |> SmartContractAdditionalSource.changeset(attrs_a) |> Repo.insert!()
      %SmartContractAdditionalSource{} |> SmartContractAdditionalSource.changeset(attrs_a_dup) |> Repo.insert!()
      %SmartContractAdditionalSource{} |> SmartContractAdditionalSource.changeset(attrs_b) |> Repo.insert!()

      # for sc2: duplicates for the same file name, independent from sc1
      attrs_c = %{address_hash: sc2.address_hash, file_name: "Common.sol", contract_source_code: "// C1"}
      attrs_c_dup = %{address_hash: sc2.address_hash, file_name: "Common.sol", contract_source_code: "// C2"}

      %SmartContractAdditionalSource{} |> SmartContractAdditionalSource.changeset(attrs_c) |> Repo.insert!()
      %SmartContractAdditionalSource{} |> SmartContractAdditionalSource.changeset(attrs_c_dup) |> Repo.insert!()

      assert MigrationStatus.get_status("sanitize_duplicate_smart_contract_additional_sources") == nil

      SanitizeDuplicateSmartContractAdditionalSources.start_link([])
      Process.sleep(150)

      # Migration completes and duplicates are deleted
      assert MigrationStatus.get_status("sanitize_duplicate_smart_contract_additional_sources") == "completed"

      remaining =
        SmartContractAdditionalSource
        |> order_by([s], asc: s.address_hash, asc: s.file_name, asc: s.id)
        |> Repo.all()

      # Expect one per (address_hash, file_name)
      grouped = Enum.group_by(remaining, &{&1.address_hash, &1.file_name})
      assert grouped |> Map.values() |> Enum.all?(fn list -> length(list) == 1 end)

      # Ensure the specific keys exist with a single row
      assert Map.has_key?(grouped, {sc1.address_hash, "FileA.sol"})
      assert Map.has_key?(grouped, {sc1.address_hash, "FileB.sol"})
      assert Map.has_key?(grouped, {sc2.address_hash, "Common.sol"})
    end

    test "completes gracefully when there are no duplicates" do
      sc = insert(:smart_contract)

      %SmartContractAdditionalSource{}
      |> SmartContractAdditionalSource.changeset(%{
        address_hash: sc.address_hash,
        file_name: "Unique.sol",
        contract_source_code: "// only"
      })
      |> Repo.insert!()

      assert MigrationStatus.get_status("sanitize_duplicate_smart_contract_additional_sources") == nil

      SanitizeDuplicateSmartContractAdditionalSources.start_link([])
      Process.sleep(100)

      assert MigrationStatus.get_status("sanitize_duplicate_smart_contract_additional_sources") == "completed"

      count = Repo.aggregate(SmartContractAdditionalSource, :count)
      assert count == 1
    end
  end
end
