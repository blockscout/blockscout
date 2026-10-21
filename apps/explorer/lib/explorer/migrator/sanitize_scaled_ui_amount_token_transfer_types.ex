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

  Tokens are taken one at a time in the order of their address, and the
  transfers of each from the newest down. The position reached is kept in the
  migration `meta`, so a batch continues the range scan of the
  `(token_contract_address_hash, block_number DESC, log_index DESC)` index
  where the previous one stopped instead of stepping over every transfer
  corrected so far.
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
  def last_unprocessed_identifiers(%{"token_contract_address_hash" => token_contract_address_hash} = state)
      when is_binary(token_contract_address_hash) do
    limit = batch_size() * concurrency()

    {ids, positions} =
      state
      |> unprocessed_data_query()
      |> order_by([token_transfer], desc: token_transfer.block_number, desc: token_transfer.log_index)
      |> select(
        [token_transfer],
        {{token_transfer.transaction_hash, token_transfer.block_hash, token_transfer.log_index},
         [token_transfer.block_number, token_transfer.log_index]}
      )
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)
      |> Enum.unzip()

    case List.last(positions) do
      nil ->
        start_next_token(state, token_contract_address_hash)

      last_position ->
        {ids, %{"token_contract_address_hash" => token_contract_address_hash, "last_position" => last_position}}
    end
  end

  def last_unprocessed_identifiers(state), do: start_next_token(state, nil)

  @impl FillingMigration
  def unprocessed_data_query(%{"token_contract_address_hash" => token_contract_address_hash} = state) do
    from(token_transfer in TokenTransfer,
      where: token_transfer.token_contract_address_hash == ^token_contract_address_hash,
      where: token_transfer.token_type != ^@token_type
    )
    |> at_or_below(state["last_position"])
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

  defp start_next_token(state, previous_token_contract_address_hash) do
    case next_token_contract_address_hash(previous_token_contract_address_hash) do
      nil ->
        {[], state}

      token_contract_address_hash ->
        last_unprocessed_identifiers(%{
          "token_contract_address_hash" => to_string(token_contract_address_hash),
          "last_position" => nil
        })
    end
  end

  defp next_token_contract_address_hash(previous_token_contract_address_hash) do
    from(token in Token,
      where: token.type == ^@token_type,
      order_by: [asc: token.contract_address_hash],
      limit: 1,
      select: token.contract_address_hash
    )
    |> after_token(previous_token_contract_address_hash)
    |> Repo.one(timeout: :infinity)
  end

  defp after_token(query, nil), do: query

  defp after_token(query, token_contract_address_hash),
    do: where(query, [token], token.contract_address_hash > ^token_contract_address_hash)

  defp at_or_below(query, nil), do: query

  # Inclusive: a reorg can leave several transfers at one position, and the
  # previous batch may have ended between them. The ones already corrected are
  # dropped by the type filter.
  defp at_or_below(query, [block_number, log_index]) do
    where(
      query,
      [token_transfer],
      fragment("(?, ?) <= (?, ?)", token_transfer.block_number, token_transfer.log_index, ^block_number, ^log_index)
    )
  end
end
