defmodule Explorer.Migrator.TokenTransferBlockConsensus do
  @moduledoc """
  Fixes token transfers block_consensus field
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.TokenTransfer
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "token_transfers_block_consensus"

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
    from(
      tt in TokenTransfer,
      join: block in assoc(tt, :block),
      where: tt.block_consensus != block.consensus
    )
  end

  @impl FillingMigration
  def update_batch(token_transfer_ids) do
    formatted_token_transfer_ids =
      Enum.map(token_transfer_ids, fn {transaction_hash, block_hash, log_index} ->
        {transaction_hash.bytes, block_hash.bytes, log_index}
      end)

    query =
      from(tt in TokenTransfer,
        join: b in assoc(tt, :block),
        where:
          fragment(
            "(?, ?, ?) = ANY(?::token_transfer_id[])",
            tt.transaction_hash,
            tt.block_hash,
            tt.log_index,
            ^formatted_token_transfer_ids
          ),
        update: [set: [block_consensus: b.consensus]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
