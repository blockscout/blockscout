defmodule Explorer.Migrator.TokenTransferTokenType do
  @moduledoc """
  Migrates all token_transfers to have set token_type
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.TokenTransfer
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "tt_denormalization"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([tt], {tt.transaction_hash, tt.block_hash, tt.log_index})
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(tt in TokenTransfer, where: is_nil(tt.token_type))
  end

  @impl FillingMigration
  def update_batch(token_transfer_ids) do
    formatted_token_transfer_ids =
      Enum.map(token_transfer_ids, fn {transaction_hash, block_hash, log_index} ->
        {transaction_hash.bytes, block_hash.bytes, log_index}
      end)

    query =
      from(tt in TokenTransfer,
        join: t in assoc(tt, :token),
        join: b in assoc(tt, :block),
        where:
          fragment(
            "(?, ?, ?) = ANY(?::token_transfer_id[])",
            tt.transaction_hash,
            tt.block_hash,
            tt.log_index,
            ^formatted_token_transfer_ids
          ),
        update: [
          set: [
            block_consensus: b.consensus,
            token_type:
              fragment(
                """
                CASE WHEN ? = 'ERC-1155' AND ? IS NULL
                THEN 'ERC-20'
                ELSE ?
                END
                """,
                t.type,
                tt.token_ids,
                t.type
              )
          ]
        ]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_tt_denormalization_finished(true)
  end
end
