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
  def last_unprocessed_identifiers do
    limit = batch_size() * concurrency()

    unprocessed_data_query()
    |> select([tt], {tt.transaction_hash, tt.block_hash, tt.log_index})
    |> limit(^limit)
    |> Repo.all(timeout: :infinity)
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
    token_transfer_ids
    |> build_update_query()
    |> Repo.query!([], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp build_update_query(token_transfer_ids) do
    """
    UPDATE token_transfers tt
    SET block_consensus = b.consensus
    FROM blocks b
    WHERE tt.block_hash = b.hash
      AND (tt.transaction_hash, tt.block_hash, tt.log_index) IN #{TokenTransfer.encode_token_transfer_ids(token_transfer_ids)};
    """
  end
end
