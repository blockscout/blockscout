defmodule Explorer.Repo.Migrations.RemoveUniqueAddressHashDecompiledContracts do
  use Ecto.Migration

  def change do
    drop(index(:decompiled_smart_contracts, [:address_hash]))

    create(
      unique_index(:decompiled_smart_contracts, [:address_hash, :decompiler_version], name: :address_decompiler_version)
    )
  end
end
