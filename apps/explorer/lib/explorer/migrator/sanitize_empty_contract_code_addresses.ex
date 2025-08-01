defmodule Explorer.Migrator.SanitizeEmptyContractCodeAddresses do
  @moduledoc """
  Migration that sets contract code to `"0x"` for addresses where contract code
  equals `null`.

  This fixes data representation for addresses of smart contracts that actually
  don't have any code deployed.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.{Address, Data, Transaction}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "sanitize_empty_contract_code_addresses"

  @empty_contract_code %Data{bytes: ""}

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([a], a.hash)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(a in Address,
      join: t in Transaction,
      on: a.hash == t.created_contract_address_hash,
      where: is_nil(a.contract_code) and t.status == :error
    )
  end

  @impl FillingMigration
  def update_batch(address_hashes) do
    query =
      from(a in Address,
        where: a.hash in ^address_hashes,
        update: [set: [contract_code: ^@empty_contract_code]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
