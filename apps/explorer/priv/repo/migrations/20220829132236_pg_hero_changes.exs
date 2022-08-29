defmodule Explorer.Repo.Migrations.DropDuplicateIndicesPgHero do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  @index_params [
    ["address_names", [:address_hash], [name: "address_names_address_hash_index", concurrently: true]],
    ["blocks", [:miner_hash], [name: "blocks_miner_hash_index", concurrently: true]],
    ["celo_contract_events", [:block_number], [name: "celo_contract_events_block_number_index", concurrently: true]],
    ["celo_signers", [:address], [name: "celo_signers_address_index", concurrently: true]],
    [
      "clabs_contract_event_trackings",
      [:smart_contract_id],
      [name: "clabs_contract_event_trackings_smart_contract_id_index", concurrently: true]
    ],
    [
      "clabs_tracked_contract_events",
      [:block_number],
      [name: "clabs_tracked_contract_events_block_number_index", concurrently: true]
    ],
    ["logs", [:block_hash, :index], [name: "logs_block_hash_index_index", concurrently: true]]
  ]

  def change do
    for params <- @index_params do
      index = apply(Ecto.Migration, :index, params)
      drop_if_exists(index)
    end
  end
end
