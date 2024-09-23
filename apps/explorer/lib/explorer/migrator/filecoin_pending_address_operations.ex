defmodule Explorer.Migrator.FilecoinPendingAddressOperations do
  @moduledoc """
  Creates a pending address operation for each address missing Filecoin address
  information, specifically when `filecoin_id`, `filecoin_robust`, and
  `filecoin_actor_type` are `nil`.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.{Address, Filecoin.PendingAddressOperation, Import}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "filecoin_pending_address_operations"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([address], address.hash)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(
      address in Address,
      left_join: op in PendingAddressOperation,
      on: address.hash == op.address_hash,
      where:
        is_nil(address.filecoin_id) and
          is_nil(address.filecoin_robust) and
          is_nil(address.filecoin_actor_type) and
          is_nil(op.address_hash),
      order_by: [asc: address.hash]
    )
  end

  @impl FillingMigration
  def update_batch(ordered_address_hashes) do
    ordered_pending_operations =
      Enum.map(
        ordered_address_hashes,
        &%{address_hash: &1}
      )

    Import.insert_changes_list(
      Repo,
      ordered_pending_operations,
      conflict_target: :address_hash,
      on_conflict: :nothing,
      for: PendingAddressOperation,
      returning: true,
      timeout: :infinity,
      timestamps: Import.timestamps()
    )
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
