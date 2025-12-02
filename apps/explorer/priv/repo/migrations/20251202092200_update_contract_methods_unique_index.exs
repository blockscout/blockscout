defmodule Explorer.Repo.Migrations.UpdateContractMethodsUniqueIndex do
  use Ecto.Migration

  def up do
    create(
      unique_index(:contract_methods, [:identifier, "md5(abi::text)"], name: :contract_methods_identifier_md5_abi_index)
    )

    create(
      index(
        :contract_methods,
        ["(abi ->> 'type')"],
        name: "contract_methods_abi_type_index"
      )
    )

    create(
      index(
        :contract_methods,
        ["(abi ->> 'name')"],
        name: "contract_methods_abi_name_index"
      )
    )

    drop(unique_index(:contract_methods, [:identifier, :abi]))
  end

  def down do
    create(unique_index(:contract_methods, [:identifier, :abi], name: :contract_methods_identifier_abi_index))

    drop(
      unique_index(:contract_methods, [:identifier, "md5(abi::text)"], name: :contract_methods_identifier_md5_abi_index)
    )

    drop(
      index(
        :contract_methods,
        ["(abi ->> 'type')"],
        name: "contract_methods_abi_type_index"
      )
    )

    drop(
      index(
        :contract_methods,
        ["(abi ->> 'name')"],
        name: "contract_methods_abi_name_index"
      )
    )
  end
end
