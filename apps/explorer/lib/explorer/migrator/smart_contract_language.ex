defmodule Explorer.Migrator.SmartContractLanguage do
  @moduledoc """
  Backfills the smart contract language field for getting rid of
  is_vyper_contract/is_yul bool flags
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Ecto.Enum
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.SmartContract
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "smart_contract_language"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([sc], sc.address_hash)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(sc in SmartContract, where: is_nil(sc.language))
  end

  @impl FillingMigration
  def update_batch(address_hashes) do
    mappings =
      SmartContract
      |> Enum.mappings(:language)
      |> Map.new()

    SmartContract
    |> where([sc], sc.address_hash in ^address_hashes)
    |> update(
      set: [
        language:
          fragment(
            """
            CASE
              WHEN is_vyper_contract THEN ?::smallint
              WHEN abi IS NULL THEN ?::smallint
              ELSE ?::smallint
            END
            """,
            ^mappings.vyper,
            ^mappings.yul,
            ^mappings.solidity
          )
      ]
    )
    |> Repo.update_all([], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_smart_contract_language_finished(true)
  end
end
