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

  use Utils.RuntimeEnvHelper,
    chain_identity: [:explorer, :chain_identity]

  import Ecto.Query

  require Logger

  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Chain.{Hash, Log, Token, TokenTransfer, Transaction}
  alias Explorer.Repo

  @erc404 "ERC-404"
  @legacy_types ["ERC-20", "ERC-721"]
  @default_rows_batch_size 1_000

  # arbitrary constant identifying the retyping of tokens to ERC-404 among
  # `pg_advisory_xact_lock` users
  @retype_advisory_lock_key 7_235_622_386_404

  # The retyping tries the exclusive lock without waiting this many times, this
  # many milliseconds apart, before it starts waiting for it, see
  # `retype_token/1`.
  @retype_try_attempts 50
  @retype_try_interval 100
  # the longest pause of the token imports per wait, and the pause between waits
  @retype_lock_timeout "500ms"
  @retype_wait_interval 2_000

  @doc """
  Returns the first topics of the events only ERC-404 tokens emit.
  """
  @spec dedicated_events() :: [String.t()]
  def dedicated_events,
    do: [TokenTransfer.erc404_erc20_transfer_event(), TokenTransfer.erc404_erc721_transfer_event()]

  @doc """
  Converts the stored data of the given token to the ERC-404 shape.

  Every statement rewrites at most `rows_batch_size` rows, in its own
  transaction, so the row locks which the block imports may wait for are held
  briefly however busy the token is. The rows are locked in the same order as
  the import runners lock them, so a conversion and an import of the same rows
  never deadlock.

  The legacy token transfers are taken from the newest to the oldest one
  through the index on the token address and the block number, which skips
  the blocks without them. The historical token balances of each batch of
  transfers are retyped right before the transfers themselves.

  Returns the number of converted token transfers.
  """
  @spec convert(Hash.Address.t(), pos_integer()) :: non_neg_integer()
  def convert(contract_address_hash, rows_batch_size \\ @default_rows_batch_size) do
    retype_token(contract_address_hash)

    converted_count = convert_token_transfers(contract_address_hash, nil, rows_batch_size, 0)

    retype_current_token_balances(contract_address_hash, rows_batch_size)

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
      # logs are stored for consensus blocks only, so the log is cataloged when a
      # consensus token transfer has its block number, index and transaction
      # position: logs of different transactions can share an index within a
      # block (see `Explorer.Chain.Log.Schema`), and the transfers of a reorged
      # block with the same number are kept
      where:
        not exists(
          from(tt in TokenTransfer.only_consensus_transfers_query(),
            join: t in Transaction,
            on: t.hash == tt.transaction_hash,
            where: tt.block_number == parent_as(:log).block_number,
            where: tt.log_index == parent_as(:log).index,
            where: t.index == parent_as(:log).transaction_index
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
    do:
      Map.merge(token_transfer, %{
        token_type: @erc404,
        amount: nil,
        token_ids: [],
        # the changes of a changeset lack the key of a nil amount
        amounts: [Map.get(token_transfer, :amount)]
      })

  def to_erc404_transfer(%{token_type: "ERC-721"} = token_transfer),
    do: Map.merge(token_transfer, %{token_type: @erc404, amount: nil, amounts: []})

  def to_erc404_transfer(token_transfer), do: token_transfer

  @doc """
  Whether the conversion of a token which is already stored as an ERC-404 one
  is incomplete.

  An interrupted conversion leaves behind legacy token transfers or, when it
  stopped after the transfer sweep, legacy current token balances, which are
  retyped last. No single row tells that the conversion is complete: the rows
  imported meanwhile get the ERC-404 shape anyway, whatever their block, and
  may update the legacy current token balances. So the remaining legacy rows
  themselves are looked for.

  The current token balances are checked first, they are few. A token whose
  conversion is complete has all its transfers read through the index on the
  token address. Callers only ask about the tokens which are converted once: an
  uncataloged token, usually a new one detected from its dedicated events, which
  has nothing to convert, and the candidates of the
  `Explorer.Migrator.SanitizeErc404Tokens` migration.
  """
  @spec conversion_pending?(Hash.Address.t()) :: boolean()
  def conversion_pending?(contract_address_hash) do
    Repo.exists?(
      from(ctb in CurrentTokenBalance,
        where: ctb.token_contract_address_hash == ^contract_address_hash,
        where: is_nil(ctb.token_id) and ctb.token_type in ^@legacy_types
      ),
      timeout: :infinity
    ) or
      Repo.exists?(
        from(tt in TokenTransfer,
          where: tt.token_contract_address_hash == ^contract_address_hash,
          where: tt.token_type in ^@legacy_types
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
  # old token type, see `legacy_erc404_token_hashes/2`. It is taken only when
  # there is a legacy type to change: the imports of a token already stored as
  # ERC-404 one read the right type.
  #
  # A waiting exclusive request holds back every new shared one, so a blocking
  # request would pause the token imports of the whole chain until the slowest
  # in-flight import commits, which may take minutes. The lock is tried without
  # waiting first, which never holds anything back. Only when the imports never
  # leave a gap, it is requested with a short `lock_timeout`, which bounds each
  # pause, and requested again after a pause long enough to let the queued
  # imports through.
  defp retype_token(contract_address_hash) do
    legacy_token_query =
      from(t in Token, where: t.contract_address_hash == ^contract_address_hash and t.type in ^@legacy_types)

    if Repo.exists?(legacy_token_query), do: retype_token(legacy_token_query, 1)
  end

  defp retype_token(legacy_token_query, attempt) do
    result =
      Repo.transaction(
        fn ->
          if lock_for_retype(attempt) do
            Repo.update_all(legacy_token_query, set: [type: @erc404, updated_at: DateTime.utc_now()])
          else
            Repo.rollback(:locked)
          end
        end,
        timeout: :infinity
      )

    case result do
      {:ok, _} ->
        :ok

      {:error, :locked} ->
        if attempt == @retype_try_attempts do
          Logger.warning("The token imports leave no gap to retype a token to ERC-404, waiting for the lock")
        end

        Process.sleep(if attempt < @retype_try_attempts, do: @retype_try_interval, else: @retype_wait_interval)
        retype_token(legacy_token_query, attempt + 1)
    end
  end

  defp lock_for_retype(attempt) when attempt < @retype_try_attempts do
    %{rows: [[locked?]]} = Repo.query!("SELECT pg_try_advisory_xact_lock($1)", [@retype_advisory_lock_key])
    locked?
  end

  defp lock_for_retype(_attempt) do
    Repo.query!("SET LOCAL lock_timeout = '#{@retype_lock_timeout}'")

    case Repo.query("SELECT pg_advisory_xact_lock($1)", [@retype_advisory_lock_key]) do
      {:ok, _} -> true
      {:error, %Postgrex.Error{postgres: %{code: :lock_not_available}}} -> false
    end
  end

  # Each batch starts at the block the previous one ended at: the transfers of
  # that block converted already are not legacy ones anymore, the rest of them
  # are taken now. A batch smaller than `rows_batch_size` is the last one.
  defp convert_token_transfers(contract_address_hash, to_block_number, rows_batch_size, converted_count) do
    case legacy_token_transfers(contract_address_hash, to_block_number, rows_batch_size) do
      [] ->
        converted_count

      batch ->
        # retyped first: no legacy token transfer left tells that the conversion
        # is complete, see `conversion_pending?/1`
        retype_token_balances(contract_address_hash, batch)
        converted_count = converted_count + convert_token_transfers_batch(contract_address_hash, batch)

        if length(batch) < rows_batch_size do
          converted_count
        else
          convert_token_transfers(
            contract_address_hash,
            List.last(batch).block_number,
            rows_batch_size,
            converted_count
          )
        end
    end
  end

  defp legacy_token_transfers(contract_address_hash, to_block_number, rows_batch_size) do
    query =
      from(tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^contract_address_hash,
        where: tt.token_type in ^@legacy_types,
        order_by: [desc: tt.block_number, desc: tt.log_index],
        limit: ^rows_batch_size,
        select: map(tt, [:block_hash, :log_index, :block_number, :from_address_hash, :to_address_hash])
      )

    query
    |> then(&if(is_nil(to_block_number), do: &1, else: where(&1, [tt], tt.block_number <= ^to_block_number)))
    |> Repo.all(timeout: :infinity)
  end

  # The same rule as the one of `to_erc404_transfer/1`. The block range lets the
  # rows be found through the index on the token address and the block number.
  defp convert_token_transfers_batch(contract_address_hash, batch) do
    {min_block_number, max_block_number} = batch |> Enum.map(& &1.block_number) |> Enum.min_max()
    block_hashes = Enum.map(batch, & &1.block_hash)
    log_indexes = Enum.map(batch, & &1.log_index)

    batch_query =
      from(tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^contract_address_hash,
        where: tt.block_number >= ^min_block_number and tt.block_number <= ^max_block_number
      )

    locked_query =
      from(tt in batch_query,
        join:
          key in fragment(
            "SELECT * FROM unnest(?::bytea[], ?::integer[]) AS key(block_hash, log_index)",
            type(^block_hashes, {:array, Hash.Full}),
            ^log_indexes
          ),
        on: tt.block_hash == key.block_hash and tt.log_index == key.log_index,
        where: tt.token_type in ^@legacy_types,
        order_by: ^token_transfers_lock_order(),
        lock: "FOR UPDATE",
        select: %{block_hash: tt.block_hash, log_index: tt.log_index}
      )

    {count, _} =
      from(tt in batch_query,
        join: locked in subquery(locked_query),
        on: tt.block_hash == locked.block_hash and tt.log_index == locked.log_index,
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

  # The import order, see `Explorer.Chain.Import.Runner.TokenTransfers`.
  defp token_transfers_lock_order do
    case chain_identity() do
      {:optimism, :celo} -> [asc: :block_hash, asc: :log_index]
      _ -> [asc: :transaction_hash, asc: :block_hash, asc: :log_index]
    end
  end

  # The token balances are found by the holders and the blocks of the given
  # token transfers, up to two per transfer: there is no index on
  # `address_token_balances` leading with the token address, while the unique
  # one leads with the holder address and the token address. They are locked in
  # the import order, see `Explorer.Chain.Import.Runner.Address.TokenBalances`.
  defp retype_token_balances(contract_address_hash, token_transfers) do
    {address_hashes, block_numbers} =
      token_transfers
      |> Enum.flat_map(&[{&1.from_address_hash, &1.block_number}, {&1.to_address_hash, &1.block_number}])
      |> Enum.uniq()
      |> Enum.unzip()

    locked_query =
      from(tb in TokenBalance,
        join:
          key in fragment(
            "SELECT * FROM unnest(?::bytea[], ?::bigint[]) AS key(address_hash, block_number)",
            type(^address_hashes, {:array, Hash.Address}),
            ^block_numbers
          ),
        on: tb.address_hash == key.address_hash and tb.block_number == key.block_number,
        where: tb.token_contract_address_hash == ^contract_address_hash,
        where: is_nil(tb.token_id) and tb.token_type in ^@legacy_types,
        order_by: [asc: tb.address_hash, asc: tb.block_number],
        lock: "FOR UPDATE",
        select: %{id: tb.id}
      )

    from(tb in TokenBalance,
      join: locked in subquery(locked_query),
      on: tb.id == locked.id,
      update: [set: [token_type: @erc404, updated_at: ^DateTime.utc_now()]]
    )
    |> Repo.update_all([], timeout: :infinity)
  end

  # Runs last, see `conversion_pending?/1`. The holders are read once, then
  # retyped in batches locked in the import order, see
  # `Explorer.Chain.Import.Runner.Address.CurrentTokenBalances`.
  defp retype_current_token_balances(contract_address_hash, rows_batch_size) do
    legacy_query =
      from(ctb in CurrentTokenBalance,
        where: ctb.token_contract_address_hash == ^contract_address_hash,
        where: is_nil(ctb.token_id) and ctb.token_type in ^@legacy_types
      )

    legacy_query
    |> order_by([ctb], asc: ctb.address_hash)
    |> select([ctb], ctb.address_hash)
    |> Repo.all(timeout: :infinity)
    |> Enum.chunk_every(rows_batch_size)
    |> Enum.each(fn address_hashes ->
      locked_query =
        from(ctb in legacy_query,
          where: ctb.address_hash in ^address_hashes,
          order_by: [asc: ctb.address_hash],
          lock: "FOR UPDATE",
          select: %{id: ctb.id}
        )

      from(ctb in CurrentTokenBalance,
        join: locked in subquery(locked_query),
        on: ctb.id == locked.id,
        update: [set: [token_type: @erc404, updated_at: ^DateTime.utc_now()]]
      )
      |> Repo.update_all([], timeout: :infinity)
    end)
  end
end
