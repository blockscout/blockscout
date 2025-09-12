defmodule Explorer.Migrator.SanitizeDuplicateSmartContractAdditionalSources do
  @moduledoc """
  Sanitizes the smart_contract_additional_sources table by removing duplicates.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.SmartContractAdditionalSource
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "sanitize_duplicate_smart_contract_additional_sources"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([t], t.id)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    query =
      from(sc in SmartContractAdditionalSource,
        select: %{
          id: sc.id,
          rn:
            fragment(
              "ROW_NUMBER() OVER (PARTITION BY ?, ? ORDER BY ?)",
              sc.address_hash,
              sc.file_name,
              sc.id
            )
        }
      )

    from(t in subquery(query), where: t.rn > 1)
  end

  @impl FillingMigration
  def update_batch(ids) do
    SmartContractAdditionalSource
    |> where([sc], sc.id in ^ids)
    |> Repo.delete_all(timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
