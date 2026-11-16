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
    type. Their values are kept: the fungible balance of an ERC-404 token is
    read with the same `balanceOf(address)` call as the one of an ERC-20 or an
    ERC-721 token.

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

            retype_token_balances(contract_address_hash, from_block_number, to_block_number)
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

  Must be called inside the import transaction, right before the insert, see
  `legacy_erc404_token_hashes/2`.
  """
  @spec normalize_imported_token_transfers(module(), [map()]) :: [map()]
  def normalize_imported_token_transfers(repo, changes_list) do
    erc404_token_hashes = legacy_erc404_token_hashes(repo, changes_list)

    Enum.map(changes_list, fn changes ->
      if MapSet.member?(erc404_token_hashes, changes.token_contract_address_hash),
        do: to_erc404_transfer(changes),
        else: changes
    end)
  end

  @doc """
  Gives the ERC-404 type to the imported historical and current token balances
  of the tokens which are stored as ERC-404 ones.

  The balances arrive with the legacy type for the same reason as the token
  transfers do, see `normalize_imported_token_transfers/2`. Legacy balances are
  fungible ones: the token id an ERC-721 balance carries is the one of the
  transfer it comes from, so it is dropped.

  Must be called inside the import transaction, right before the insert, see
  `legacy_erc404_token_hashes/2`.
  """
  @spec normalize_imported_token_balances(module(), [map()]) :: [map()]
  def normalize_imported_token_balances(repo, changes_list) do
    erc404_token_hashes = legacy_erc404_token_hashes(repo, changes_list)

    Enum.map(changes_list, fn changes ->
      if MapSet.member?(erc404_token_hashes, changes.token_contract_address_hash) and
           changes[:token_type] in @legacy_types,
         do: changes |> Map.delete(:token_id) |> Map.put(:token_type, @erc404),
         else: changes
    end)
  end

  @doc """
  Gives the ERC-404 shape to an ERC-20 or ERC-721 leg of an ERC-404 token
  transfer: the fungible amount goes to `amounts`, `amount` is not used at all,
  the same way as for the transfers parsed from the dedicated ERC-404 events.
  Other transfers are returned as they are.

  The stored transfers are converted by the same rule in SQL, see `convert/2`.
  """
  @spec to_erc404_transfer(map()) :: map()
  def to_erc404_transfer(%{token_type: "ERC-20"} = token_transfer),
    do: Map.merge(token_transfer, %{token_type: @erc404, amount: nil, token_ids: [], amounts: [token_transfer.amount]})

  def to_erc404_transfer(%{token_type: "ERC-721"} = token_transfer),
    do: Map.merge(token_transfer, %{token_type: @erc404, amount: nil, amounts: []})

  def to_erc404_transfer(token_transfer), do: token_transfer

  @doc """
  Whether the conversion of a token which is already stored as an ERC-404 one
  is incomplete.

  The current token balances are retyped last by `convert/2`, so the legacy
  ones are left behind by an interrupted conversion only. A token detected as
  ERC-404 from its dedicated events has none of them, so nothing is converted
  for it.
  """
  @spec conversion_pending?(Hash.Address.t()) :: boolean()
  def conversion_pending?(contract_address_hash) do
    Repo.exists?(
      from(ctb in CurrentTokenBalance,
        where: ctb.token_contract_address_hash == ^contract_address_hash,
        where: is_nil(ctb.token_id) and ctb.token_type in ^@legacy_types
      ),
      timeout: :infinity
    )
  end

  # Returns the tokens of the legacy-typed changes which are stored as ERC-404
  # ones. The token types are re-read under the shared advisory lock, which the
  # retyping takes exclusively: either the retyping waits for the import to
  # commit, and the following conversion sweep converts the imported rows, or
  # the import waits for the retyping and sees the ERC-404 type here.
  #
  # The lock is taken before any row lock of the import transaction, the same
  # way as by the retyping.
  defp legacy_erc404_token_hashes(repo, changes_list) do
    legacy_token_hashes =
      changes_list
      |> Enum.filter(&(&1[:token_type] in @legacy_types))
      |> Enum.map(& &1.token_contract_address_hash)
      |> Enum.uniq()

    if legacy_token_hashes == [] do
      MapSet.new()
    else
      repo.query!("SELECT pg_advisory_xact_lock_shared($1)", [@retype_advisory_lock_key])

      from(t in Token,
        where: t.contract_address_hash in ^legacy_token_hashes and t.type == ^@erc404,
        select: t.contract_address_hash
      )
      |> repo.all()
      |> MapSet.new()
    end
  end

  # The exclusive advisory lock waits for the imports which might have read the
  # old token type, see `legacy_erc404_token_hashes/2`, and holds back the new
  # ones meanwhile. It is taken only when there is a legacy type to change: the
  # imports of a token already stored as ERC-404 one read the right type.
  defp retype_token(contract_address_hash) do
    legacy_token_query =
      from(t in Token, where: t.contract_address_hash == ^contract_address_hash and t.type in ^@legacy_types)

    if Repo.exists?(legacy_token_query) do
      {:ok, _} =
        Repo.transaction(
          fn ->
            Repo.query!("SELECT pg_advisory_xact_lock($1)", [@retype_advisory_lock_key])
            Repo.update_all(legacy_token_query, set: [type: @erc404, updated_at: DateTime.utc_now()])
          end,
          timeout: :infinity
        )
    end
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

  # The same rule as the one of `to_erc404_transfer/1`.
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
  defp retype_token_balances(contract_address_hash, from_block_number, to_block_number) do
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
        set: [token_type: @erc404, updated_at: ^DateTime.utc_now()]
      ]
    )
    |> Repo.update_all([], timeout: :infinity)
  end

  # Runs last, so that `conversion_pending?/1` tells an interrupted conversion.
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
