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
  def last_unprocessed_identifiers do
    limit = batch_size() * concurrency()

    unprocessed_data_query()
    |> select([tt], {tt.transaction_hash, tt.block_hash, tt.log_index})
    |> limit(^limit)
    |> Repo.all(timeout: :infinity)
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(tt in TokenTransfer, where: is_nil(tt.token_type))
  end

  @impl FillingMigration
  def update_batch(token_transfer_ids) do
    token_transfer_ids
    |> build_update_query()
    |> Repo.query!([], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_tt_denormalization_finished(true)
  end

  defp build_update_query(token_transfer_ids) do
    """
    UPDATE token_transfers tt
    SET token_type = CASE WHEN t.type = 'ERC-1155' AND token_ids IS NULL THEN 'ERC-20'
                          ELSE t.type
                     END,
        block_consensus = b.consensus
    FROM tokens t, blocks b
    WHERE tt.block_hash = b.hash
      AND tt.token_contract_address_hash = t.contract_address_hash
      AND (tt.transaction_hash, tt.block_hash, tt.log_index) IN #{TokenTransfer.encode_token_transfer_ids(token_transfer_ids)};
    """
  end
end
