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
    BackgroundMigrations.set_tb_token_type_finished(true)
  end

  defp build_update_query(token_transfer_ids) do
    """
    UPDATE token_transfers tt
    SET token_type = t.type
    FROM tokens t
    WHERE tt.token_contract_address_hash = t.contract_address_hash
      AND (tt.transaction_hash, tt.block_hash, tt.log_index) IN #{encode_token_transfer_ids(token_transfer_ids)};
    """
  end

  defp encode_token_transfer_ids(ids) do
    encoded_values =
      ids
      |> Enum.reduce("", fn {t_hash, b_hash, log_index}, acc ->
        acc <> "('#{hash_to_query_string(t_hash)}', '#{hash_to_query_string(b_hash)}', #{log_index}),"
      end)
      |> String.trim_trailing(",")

    "(#{encoded_values})"
  end

  defp hash_to_query_string(hash) do
    s_hash =
      hash
      |> to_string()
      |> String.trim_leading("0")

    "\\#{s_hash}"
  end
end
