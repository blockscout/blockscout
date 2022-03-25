defmodule Explorer.Repo.Migrations.SetCoreContractForeignKeyOnEvents do
  use Ecto.Migration
  import Ecto.Query
  require Logger

  def up do
    # delete events where contract_address_hash is not referenced in celo_core_contracts table
    [block_numbers, indices] =
      from(cce in "celo_contract_events",
        left_join: ccc in "celo_core_contracts",
        on: cce.contract_address_hash == ccc.address_hash,
        where: is_nil(ccc.address_hash),
        select: [:block_number, :log_index]
      )
      |> repo().all()
      |> Enum.reduce([[], []], fn %{block_number: bn, log_index: li}, [numbers, indices] ->
        [[bn | numbers], [li | indices]]
      end)

    {deleted_row_count, _} =
      from(
        cce in "celo_contract_events",
        join:
          v in fragment("SELECT * FROM unnest(?::int[], ?::int[]) AS v(block_number,index)", ^block_numbers, ^indices),
        on: v.block_number == cce.block_number and cce.log_index == v.index
      )
      |> repo().delete_all()

    Logger.info("Deleted #{deleted_row_count} rows from celo_contracts_events")

    # set address_hash to have a foreign key constraint on core_contracts
    drop(constraint("celo_contract_events", "contract_address_hash"))

    alter table("celo_contract_events") do
      modify(
        :contract_address_hash,
        references("celo_core_contracts", column: :address_hash, type: :bytea, name: :contract_address_hash)
      )
    end
  end

  def down do
    drop(constraint("celo_contract_events", "contract_address_hash"))

    alter table("celo_contract_events") do
      modify(:contract_address_hash, references("addresses", column: :hash, type: :bytea, name: :contract_address_hash))
    end
  end
end
