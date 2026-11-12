# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.SanitizeEip7708TokenTransfers do
  @moduledoc """
  Deletes token transfers that were wrongly derived from EIP-7708 protocol `Transfer` logs
  emitted by `SYSTEM_ADDRESS` (`0xffff...fffe`), together with the token balances and the
  token record of that pseudo-token.

  On chain types without a native-token mapping for these logs they mirror native coin
  movements that are already tracked as transaction values and internal transactions,
  so storing them as ERC-20 transfers of a metadata-less token only produces noise
  (bogus token transfers in the API/UI and duplicate watchlist notifications).
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Chain.{Hash, Token, TokenTransfer}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "sanitize_eip7708_token_transfers"

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
    from(tt in TokenTransfer, where: tt.token_contract_address_hash == ^system_address_hash())
  end

  @impl FillingMigration
  def update_batch(token_transfer_ids) do
    {count, _} =
      token_transfer_ids
      |> TokenTransfer.by_ids_query()
      |> Repo.delete_all(timeout: :infinity)

    count
  end

  @impl FillingMigration
  def on_finish do
    hash = system_address_hash()

    Repo.delete_all(from(ctb in CurrentTokenBalance, where: ctb.token_contract_address_hash == ^hash),
      timeout: :infinity
    )

    Repo.delete_all(from(tb in TokenBalance, where: tb.token_contract_address_hash == ^hash), timeout: :infinity)
    Repo.delete_all(from(t in Token, where: t.contract_address_hash == ^hash), timeout: :infinity)

    :ok
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp system_address_hash do
    {:ok, hash} = Hash.Address.cast(TokenTransfer.eip7708_system_address())
    hash
  end
end
