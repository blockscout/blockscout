# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.SanitizeScaledUIAmountTokenTransferTypes do
  @moduledoc """
  Corrects the denormalized `token_transfers.token_type` of ERC-8056 tokens.

  ERC-8056 cannot be told from a log — such a token emits the plain ERC-20
  `Transfer` — so its transfers were indexed as `ERC-20` long before the token
  itself was typed `ERC-8056`. That both hides them from a filter by `ERC-8056`
  and shows them under one by `ERC-20`.

  Runs after `Explorer.Migrator.BackfillScaledUIAmountTokens`, which is what
  types the tokens in the first place, and after
  `Explorer.Migrator.TokenTransferTokenType`: until the latter has finished a
  token type filter joins `tokens` and reads the current type rather than the
  denormalized column, so there is nothing to correct yet.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.{Token, TokenTransfer}
  alias Explorer.Migrator.{BackfillScaledUIAmountTokens, FillingMigration, TokenTransferTokenType}
  alias Explorer.Repo

  @migration_name "sanitize_scaled_ui_amount_token_transfer_types"
  @token_type "ERC-8056"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def dependent_from_migrations,
    do: [
      BackfillScaledUIAmountTokens.migration_name(),
      TokenTransferTokenType.migration_name()
    ]

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select(
        [token_transfer],
        {token_transfer.transaction_hash, token_transfer.block_hash, token_transfer.log_index}
      )
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    scaled_ui_amount_tokens =
      from(token in Token, where: token.type == ^@token_type, select: token.contract_address_hash)

    from(token_transfer in TokenTransfer,
      where: token_transfer.token_type != ^@token_type,
      where: token_transfer.token_contract_address_hash in subquery(scaled_ui_amount_tokens)
    )
  end

  @impl FillingMigration
  def update_batch(token_transfer_ids) do
    {count, _} =
      token_transfer_ids
      |> TokenTransfer.by_ids_query()
      |> update(set: [token_type: ^@token_type])
      |> Repo.update_all([], timeout: :infinity)

    count
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
