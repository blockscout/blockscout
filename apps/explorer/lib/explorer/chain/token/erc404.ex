# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Token.Erc404 do
  @moduledoc """
  Converts the stored data of a token that turned out to be an
  [ERC-404](https://github.com/Pandora-Labs-Org/erc404) token, but was indexed
  as an ERC-721 or an ERC-20 one.

  ERC-404 tokens come in two flavours:

  * the ones emitting the dedicated `ERC20Transfer` or `ERC721Transfer` events
    next to the standard `Transfer` one. Those events are only parsed into
    token transfers since ERC-404 support was added, so the tokens which were
    active before that keep their old type and their dedicated events stay
    uncataloged;
  * the ones emitting the standard `Transfer` event for both legs: with 3 topics
    for the fungible amount and with 4 topics for the NFT id. Their legs are
    parsed as ERC-20 and ERC-721 transfers, and the token itself is resolved to
    ERC-721.

  The conversion makes the stored data look the same as the one the indexer
  produces for an ERC-404 token:

  * the token gets the ERC-404 type;
  * its ERC-20 transfers become ERC-404 ones with `amounts: [amount]` and
    `token_ids: []`, its ERC-721 transfers become ERC-404 ones with
    `amounts: []`;
  * its fungible token balances (the ones without a token id) get the ERC-404
    type and are marked as unfetched, so that the token balance fetcher reads
    them again as ERC-404 balances.

  Blocks with uncataloged `ERC20Transfer` and `ERC721Transfer` logs are not
  handled here, see `uncataloged_log_block_numbers/2`.

  Every step only touches the rows which are not converted yet, so the
  conversion can safely run more than once for the same token.
  """

  import Ecto.Query

  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Chain.{Hash, Log, Token, TokenTransfer}
  alias Explorer.Repo

  @erc404 "ERC-404"
  @legacy_types ["ERC-20", "ERC-721"]
  @default_blocks_batch_size 10_000

  # arbitrary constant identifying the retyping of tokens to ERC-404 among
  # `pg_advisory_xact_lock` users
  @retype_advisory_lock_key 7_235_622_386_404

  @doc """
  Returns the first topics of the events only ERC-404 tokens emit.
  """
  @spec dedicated_events() :: [String.t()]
  def dedicated_events,
    do: [TokenTransfer.erc404_erc20_transfer_event(), TokenTransfer.erc404_erc721_transfer_event()]

  @doc """
  Converts the stored data of the given token to the ERC-404 shape.

  The token transfers and the historical token balances are processed in
  windows of `blocks_batch_size` blocks, from the newest to the oldest one, so
  that no single statement locks the whole history of a busy token.

  Returns the number of converted token transfers.
  """
  @spec convert(Hash.Address.t(), pos_integer()) :: non_neg_integer()
  def convert(contract_address_hash, blocks_batch_size \\ @default_blocks_batch_size) do
    retype_token(contract_address_hash)

    converted_count =
      case token_transfers_block_range(contract_address_hash) do
        {min_block_number, max_block_number} when not is_nil(min_block_number) ->
          max_block_number
          |> Stream.iterate(&(&1 - blocks_batch_size))
          |> Stream.take_while(&(&1 >= min_block_number))
          |> Enum.reduce(0, fn to_block_number, acc ->
            from_block_number = max(to_block_number - blocks_batch_size + 1, min_block_number)

            reset_token_balances(contract_address_hash, from_block_number, to_block_number)
            acc + convert_token_transfers(contract_address_hash, from_block_number, to_block_number)
          end)

        _ ->
          0
      end

    retype_current_token_balances(contract_address_hash)

    converted_count
  end

  @doc """
  Returns the numbers of the blocks starting from `from_block_number` which
  contain `ERC20Transfer` or `ERC721Transfer` logs of the given token without a
  token transfer.

  Such logs were emitted before ERC-404 support was added to the indexer, and
  the only way to catalog them is to re-fetch their blocks.
  """
  @spec uncataloged_log_block_numbers(Hash.Address.t(), non_neg_integer()) :: [non_neg_integer()]
  def uncataloged_log_block_numbers(contract_address_hash, from_block_number \\ 0) do
    from(l in Log,
      as: :log,
      where: ^Log.address_match_dynamic(contract_address_hash),
      where: ^Log.topic_filter_dynamic(:first_topic, dedicated_events()),
      where: l.block_number >= ^from_block_number,
      # a block keeps only one log with the given index, which is enough to tell
      # whether the log has been cataloged; the block hash rules out the transfers
      # of a reorged block with the same number
      where:
        not exists(
          from(tt in TokenTransfer,
            where: tt.block_number == parent_as(:log).block_number,
            where: tt.block_hash == parent_as(:log).block_hash,
            where: tt.log_index == parent_as(:log).index
          )
        ),
      distinct: true,
      select: l.block_number
    )
    |> Repo.all(timeout: :infinity)
  end

  @doc """
  Gives the ERC-404 shape to the imported token transfers of the tokens which
  are stored as ERC-404 ones.

  The block fetcher derives the token transfer types from the token types it
  read before the import, so the transfers of a token retyped in the meantime
  arrive with the ERC-20 and ERC-721 shapes. They would be inserted after the
  conversion swept the token, or would revert its converted transfers on
  conflict.

  Must be called inside the import transaction, right before the insert. The
  token types are re-read under the shared advisory lock, which the retyping
  takes exclusively: either the retyping waits for the import to commit, and the
  following conversion sweep converts the imported transfers, or the import
  waits for the retyping and sees the ERC-404 type here.
  """
  @spec normalize_imported_token_transfers(module(), [map()]) :: [map()]
  def normalize_imported_token_transfers(repo, changes_list) do
    legacy_token_hashes =
      changes_list
      |> Enum.filter(&(&1[:token_type] in @legacy_types))
      |> Enum.map(& &1.token_contract_address_hash)
      |> Enum.uniq()

    if legacy_token_hashes == [] do
      changes_list
    else
      repo.query!("SELECT pg_advisory_xact_lock_shared($1)", [@retype_advisory_lock_key])

      erc404_token_hashes =
        from(t in Token,
          where: t.contract_address_hash in ^legacy_token_hashes and t.type == ^@erc404,
          select: t.contract_address_hash
        )
        |> repo.all()
        |> MapSet.new()

      Enum.map(changes_list, &maybe_to_erc404_shape(&1, erc404_token_hashes))
    end
  end

  defp maybe_to_erc404_shape(%{token_type: token_type} = changes, erc404_token_hashes)
       when token_type in @legacy_types do
    if MapSet.member?(erc404_token_hashes, changes.token_contract_address_hash),
      do: to_erc404_shape(changes),
      else: changes
  end

  defp maybe_to_erc404_shape(changes, _erc404_token_hashes), do: changes

  defp to_erc404_shape(%{token_type: "ERC-20"} = changes),
    do: Map.merge(changes, %{token_type: @erc404, amount: nil, token_ids: [], amounts: [changes[:amount]]})

  defp to_erc404_shape(changes), do: Map.merge(changes, %{token_type: @erc404, amount: nil, amounts: []})

  # The exclusive advisory lock waits for the imports of token transfers which
  # might have read the old token type, see `normalize_imported_token_transfers/2`.
  defp retype_token(contract_address_hash) do
    {:ok, _} =
      Repo.transaction(
        fn ->
          Repo.query!("SELECT pg_advisory_xact_lock($1)", [@retype_advisory_lock_key])

          Repo.update_all(
            from(t in Token, where: t.contract_address_hash == ^contract_address_hash and t.type in ^@legacy_types),
            set: [type: @erc404, updated_at: DateTime.utc_now()]
          )
        end,
        timeout: :infinity
      )
  end

  defp token_transfers_block_range(contract_address_hash) do
    Repo.one(
      from(tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^contract_address_hash,
        select: {min(tt.block_number), max(tt.block_number)}
      ),
      timeout: :infinity
    )
  end

  # The legs of ERC-404 tokens are stored the same way as the transfers parsed
  # from the dedicated ERC-404 events: the fungible amount goes to `amounts`,
  # `amount` is not used at all.
  defp convert_token_transfers(contract_address_hash, from_block_number, to_block_number) do
    {count, _} =
      from(tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^contract_address_hash,
        where: tt.block_number >= ^from_block_number and tt.block_number <= ^to_block_number,
        where: tt.token_type in ^@legacy_types,
        update: [
          set: [
            token_type: @erc404,
            amounts:
              fragment(
                "CASE WHEN ? = 'ERC-20' THEN ARRAY[?] ELSE '{}'::numeric[] END",
                tt.token_type,
                tt.amount
              ),
            token_ids: fragment("CASE WHEN ? = 'ERC-20' THEN '{}'::numeric[] ELSE ? END", tt.token_type, tt.token_ids),
            amount: nil,
            updated_at: ^DateTime.utc_now()
          ]
        ]
      )
      |> Repo.update_all([], timeout: :infinity)

    count
  end

  # Token balances are found through the token transfers of the window: there is
  # no index on `address_token_balances` leading with the token address, while
  # the unique one leads with the holder address and the token address.
  defp reset_token_balances(contract_address_hash, from_block_number, to_block_number) do
    holders_query =
      from(tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^contract_address_hash,
        where: tt.block_number >= ^from_block_number and tt.block_number <= ^to_block_number,
        distinct: true,
        select: %{
          address_hash: type(fragment("unnest(ARRAY[?, ?])", tt.from_address_hash, tt.to_address_hash), Hash.Address),
          block_number: tt.block_number
        }
      )

    from(tb in TokenBalance,
      join: holder in subquery(holders_query),
      on: tb.address_hash == holder.address_hash and tb.block_number == holder.block_number,
      where: tb.token_contract_address_hash == ^contract_address_hash,
      where: is_nil(tb.token_id) and tb.token_type in ^@legacy_types,
      update: [
        set: [
          token_type: @erc404,
          value_fetched_at: nil,
          refetch_after: nil,
          retries_count: nil,
          updated_at: ^DateTime.utc_now()
        ]
      ]
    )
    |> Repo.update_all([], timeout: :infinity)
  end

  # The values themselves are replaced as soon as the token balance fetcher reads
  # the reset token balances: their `value_fetched_at` is newer than the one of
  # the current token balances.
  defp retype_current_token_balances(contract_address_hash) do
    Repo.update_all(
      from(ctb in CurrentTokenBalance,
        where: ctb.token_contract_address_hash == ^contract_address_hash,
        where: is_nil(ctb.token_id) and ctb.token_type in ^@legacy_types
      ),
      [set: [token_type: @erc404, updated_at: DateTime.utc_now()]],
      timeout: :infinity
    )
  end
end
