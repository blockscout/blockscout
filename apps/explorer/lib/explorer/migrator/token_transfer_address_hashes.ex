defmodule Explorer.Migrator.TokenTransferAddressHashes do
  @moduledoc """
  Migrates all token_transfers to have set address_hashes
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.TokenTransfer
  alias Explorer.Migrator.{FillingMigration, TokenTransferTokenType}
  alias Explorer.Repo

  @migration_name "tt_address_hashes_backfilling"

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
    from(tt in TokenTransfer, where: is_nil(tt.address_hashes))
  end

  @impl FillingMigration
  def update_batch(token_transfer_ids) do
    token_transfer_ids
    |> build_update_query()
    |> Repo.query!([], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_tt_address_hashes_backfilling_finished(true)
  end

  defp build_update_query(token_transfer_ids) do
    """
    UPDATE token_transfers tt
    SET address_hashes = ARRAY[tt.from_address_hash, tt.to_address_hash]
    WHERE (tt.transaction_hash, tt.block_hash, tt.log_index) IN #{TokenTransferTokenType.encode_token_transfer_ids(token_transfer_ids)};
    """
  end
end
