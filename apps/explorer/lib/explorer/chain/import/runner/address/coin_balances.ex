# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.Address.CoinBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.CoinBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.{Block, Hash, Import, PendingOperationsHelper, Wei}
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [
          %{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}
        ]

  @impl Import.Runner
  def ecto_schema_module, do: CoinBalance

  @impl Import.Runner
  def option_key, do: :address_coin_balances

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[%{address_hash: Explorer.Chain.Hash.t(), block_number: Explorer.Chain.Block.block_number()}]",
      value_description: "List of  maps of the `t:#{ecto_schema_module()}.t/0` `address_hash` and `block_number`"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :address_coin_balances, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :address_referencing,
        :coin_balances,
        :address_coin_balances
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(
          Repo.t(),
          [
            %{
              required(:address_hash) => Hash.Address.t(),
              required(:block_number) => Block.block_number(),
              required(:value) => Wei.t()
            }
          ],
          %{
            optional(:on_conflict) => Import.Runner.on_conflict(),
            required(:timeout) => timeout,
            required(:timestamps) => Import.timestamps()
          }
        ) ::
          {:ok, [%{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce CoinBalance ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.address_hash, &1.block_number})
      |> Enum.dedup()

    importable_changes_list = reject_unchanged(repo, ordered_changes_list, timeout)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        importable_changes_list,
        conflict_target: [:address_hash, :block_number],
        on_conflict: on_conflict,
        for: CoinBalance,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, Enum.map(importable_changes_list, &Map.take(&1, ~w(address_hash block_number value)a))}
  end

  # Drops fetched balances whose value is the same as in the previous coin balance
  # row of the address, so that the table keeps only balance changes.
  #
  # The table doubles as the fetch queue: a placeholder row (`value` is `nil`) is
  # inserted on block import and filled in later by the coin balance fetchers. The
  # comparison is made before the placeholder is filled in, and the placeholder of
  # an unchanged balance is deleted instead of being updated and deleted afterwards.
  #
  # Params without a value (placeholders) are never dropped.
  defp reject_unchanged(repo, changes_list, timeout) do
    fetched_changes = Enum.filter(changes_list, &(not is_nil(Map.get(&1, :value))))

    if fetched_changes == [] or not unchanged_rejection_enabled?() do
      changes_list
    else
      unchanged_keys = unchanged_keys(repo, fetched_changes, timeout)

      if MapSet.size(unchanged_keys) == 0 do
        changes_list
      else
        delete_placeholders(repo, unchanged_keys, timeout)
        Enum.reject(changes_list, &MapSet.member?(unchanged_keys, key(&1)))
      end
    end
  end

  # A balance equal to the previous one can only be dropped when no row can show
  # up between the two later on. A row that arrives afterwards with another value
  # would otherwise become the latest known balance for the dropped block.
  #
  # Rows come late from blocks that are not imported yet (covered by the
  # `missing_block_ranges` check) and from internal transactions that are not
  # fetched yet. The latter can be checked cheaply only when pending operations
  # are tracked per block, so with per-transaction pending operations nothing is
  # dropped while the internal transactions fetcher is enabled.
  defp unchanged_rejection_enabled? do
    internal_transactions_fetcher_disabled?() or PendingOperationsHelper.pending_operations_type() == "blocks"
  end

  defp internal_transactions_fetcher_disabled? do
    Application.get_env(:indexer, Indexer.Fetcher.InternalTransaction.Supervisor)[:disabled?] == true
  end

  defp unchanged_keys(repo, fetched_changes, timeout) do
    existing_values = lock_existing_rows(repo, fetched_changes, timeout)

    # a row that already has a value is being re-fetched and goes through the upsert
    candidates = Enum.filter(fetched_changes, &is_nil(Map.get(existing_values, key(&1))))

    batch_values = Map.new(fetched_changes, &{key(&1), &1.value})

    repo
    |> previous_rows(candidates, timeout)
    |> Enum.reduce(MapSet.new(), fn previous_row, acc ->
      key = {previous_row.address_hash, previous_row.block_number}
      previous_key = {previous_row.address_hash, previous_row.previous_block_number}

      # the previous row may be a placeholder that is filled in by this very batch
      previous_value = previous_row.previous_value || Map.get(batch_values, previous_key)

      if not previous_row.unsettled? and same_value?(Map.fetch!(batch_values, key), previous_value) do
        MapSet.put(acc, key)
      else
        acc
      end
    end)
  end

  # Locks the rows of the batch that already exist, in the ShareLocks order, and
  # returns their current values. Both the delete of unchanged placeholders and the
  # upsert of the rest then operate on rows that are already locked.
  defp lock_existing_rows(repo, fetched_changes, timeout) do
    {address_hashes, block_numbers} = unzip_keys(fetched_changes)

    query =
      from(cb in CoinBalance,
        where:
          fragment(
            "(?, ?) IN (SELECT * FROM unnest(?, ?))",
            cb.address_hash,
            cb.block_number,
            type(^address_hashes, {:array, Hash.Address}),
            type(^block_numbers, {:array, :integer})
          ),
        order_by: [asc: cb.address_hash, asc: cb.block_number],
        select: {cb.address_hash, cb.block_number, cb.value},
        lock: "FOR UPDATE"
      )

    query
    |> repo.all(timeout: timeout)
    |> Map.new(fn {address_hash, block_number, value} -> {{address_hash.bytes, block_number}, value} end)
  end

  # For every candidate returns the nearest older row of the address and whether
  # the block range between the two is still unsettled.
  defp previous_rows(_repo, [], _timeout), do: []

  defp previous_rows(repo, candidates, timeout) do
    {address_hashes, block_numbers} = unzip_keys(candidates)
    check_pending_block_operations? = not internal_transactions_fetcher_disabled?()

    previous_row_query =
      from(cb in CoinBalance,
        where:
          cb.address_hash == parent_as(:pair).address_hash and
            cb.block_number < parent_as(:pair).block_number,
        order_by: [desc: cb.block_number],
        limit: 1,
        select: %{address_hash: cb.address_hash, block_number: cb.block_number, value: cb.value}
      )

    query =
      from(
        pair in fragment(
          "SELECT * FROM unnest(?, ?) AS pair(address_hash, block_number)",
          type(^address_hashes, {:array, Hash.Address}),
          type(^block_numbers, {:array, :integer})
        ),
        as: :pair,
        inner_lateral_join: previous in subquery(previous_row_query),
        on: true,
        select: %{
          address_hash: previous.address_hash,
          block_number: type(pair.block_number, :integer),
          previous_block_number: previous.block_number,
          previous_value: previous.value,
          unsettled?:
            fragment(
              """
              EXISTS (
                SELECT 1 FROM missing_block_ranges AS mbr
                WHERE mbr.to_number < ? AND mbr.from_number > ?
              ) OR (
                ? AND EXISTS (
                  SELECT 1 FROM pending_block_operations AS pbo
                  WHERE pbo.block_number > ? AND pbo.block_number < ?
                )
              )
              """,
              pair.block_number,
              previous.block_number,
              ^check_pending_block_operations?,
              previous.block_number,
              pair.block_number
            )
        }
      )

    query
    |> repo.all(timeout: timeout)
    |> Enum.map(&%{&1 | address_hash: &1.address_hash.bytes})
  end

  defp delete_placeholders(repo, keys, timeout) do
    {address_hashes, block_numbers} = keys |> Enum.sort() |> Enum.unzip()

    query =
      from(cb in CoinBalance,
        where:
          fragment(
            "(?, ?) IN (SELECT * FROM unnest(?::bytea[], ?))",
            cb.address_hash,
            cb.block_number,
            ^address_hashes,
            type(^block_numbers, {:array, :integer})
          ),
        where: is_nil(cb.value)
      )

    repo.delete_all(query, timeout: timeout)
  end

  defp unzip_keys(changes_list) do
    changes_list
    |> Enum.map(&{&1.address_hash, &1.block_number})
    |> Enum.unzip()
  end

  defp key(%{address_hash: %Hash{bytes: bytes}, block_number: block_number}), do: {bytes, block_number}

  defp key(%{address_hash: address_hash, block_number: block_number}) when is_binary(address_hash) do
    {:ok, %Hash{bytes: bytes}} = Hash.Address.cast(address_hash)
    {bytes, block_number}
  end

  defp same_value?(_value, nil), do: false
  defp same_value?(value, previous_value), do: Decimal.eq?(to_decimal(value), to_decimal(previous_value))

  defp to_decimal(%Wei{value: value}), do: value
  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)

  def default_on_conflict do
    from(
      balance in CoinBalance,
      update: [
        set: [
          value:
            fragment(
              """
              CASE WHEN EXCLUDED.value IS NOT NULL AND (? IS NULL OR EXCLUDED.value_fetched_at > ?) THEN
                     EXCLUDED.value
                   ELSE
                     ?
              END
              """,
              balance.value_fetched_at,
              balance.value_fetched_at,
              balance.value
            ),
          value_fetched_at:
            fragment(
              """
              CASE WHEN EXCLUDED.value IS NOT NULL AND (? IS NULL OR EXCLUDED.value_fetched_at > ?) THEN
                     EXCLUDED.value_fetched_at
                   ELSE
                     ?
              END
              """,
              balance.value_fetched_at,
              balance.value_fetched_at,
              balance.value_fetched_at
            ),
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", balance.inserted_at),
          updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", balance.updated_at)
        ]
      ],
      where:
        fragment("EXCLUDED.value IS NOT NULL") and
          (is_nil(balance.value_fetched_at) or fragment("EXCLUDED.value_fetched_at > ?", balance.value_fetched_at))
    )
  end
end
