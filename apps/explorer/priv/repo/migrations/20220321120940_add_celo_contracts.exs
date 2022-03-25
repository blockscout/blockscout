defmodule Explorer.Repo.Migrations.AddCeloContracts do
  use Ecto.Migration
  alias Explorer.Celo.ContractEvents.Registry.RegistryUpdatedEvent

  alias Explorer.Chain.Hash.Address

  def up do
    create table(:celo_core_contracts, primary_key: false) do
      add(:address_hash, :bytea, null: false, primary_key: true)
      add(:name, :string, null: false)
      add(:block_number, :integer)
      add(:log_index, :integer)

      timestamps()
    end

    flush()

    {:ok, registry_hash} = Address.cast("0x000000000000000000000000000000000000ce10")
    {:ok, registry_bytea} = registry_hash |> Address.dump()

    registry_contract = %{
      name: "Registry",
      address_hash: registry_bytea,
      block_number: 1,
      log_index: 0
    }

    # get all core contracts (registry entries)
    core_contracts =
      RegistryUpdatedEvent.raw_registry_updated_logs()
      |> repo().all()
      |> Explorer.Celo.ContractEvents.EventMap.rpc_to_event_params()
      |> Enum.map(fn e ->
        {:ok, hsh} = Address.cast(e.params.addr)
        {:ok, address_bytea} = hsh |> Address.dump()

        %{name: e.params.identifier, address_hash: address_bytea, block_number: e.block_number, log_index: e.log_index}
      end)
      |> then(&[registry_contract | &1])
      |> Enum.map(fn e ->
        e
        |> Map.put(:inserted_at, Timex.now())
        |> Map.put(:updated_at, Timex.now())
      end)

    # insert into new table
    contract_length = length(core_contracts)
    {^contract_length, _} = repo().insert_all("celo_core_contracts", core_contracts)
  end

  def down do
    drop(table(:celo_core_contracts))
  end
end
