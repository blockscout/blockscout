# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.InternalTransactionsAddressPlaceholder do
  @moduledoc """
  Module is responsible for keeping the information about the presence of internal transactions
  on a particular address inside specific block
  """

  use Explorer.Schema

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Repo

  @primary_key false
  typed_schema "deleted_internal_transactions_address_placeholders" do
    field(:address_id, :integer, primary_key: true)
    field(:block_number, :integer, primary_key: true)
    field(:count_tos, :integer)
    field(:count_froms, :integer)
  end

  @smallint_max_value 32_767
  @insert_batch_size 1000

  @doc false
  def changeset(placeholder \\ %__MODULE__{}, params) do
    cast(placeholder, params, [:address_id, :block_number, :count_tos, :count_froms])
  end

  @spec empty?() :: boolean()
  def empty? do
    not Repo.exists?(__MODULE__)
  end

  @doc """
  Stores the placeholders of the given internal transactions, which are not stored themselves: for each address and
  block, the number of the internal transactions to (`count_tos`) and from (`count_froms`) the address.

  First traces (index 0) are skipped, as they represent the transactions themselves. The counts are added to the
  existing placeholders of the same address and block: the internal transactions of a block can come in several
  batches (with pending transaction operations), and each internal transaction comes once, unless its block is
  processed again. Such blocks get their placeholders deleted first (see `delete_by_block_numbers/3`).

  ## Parameters
  - `repo`: The repo to insert with
  - `internal_transactions`: Maps with `block_number`, `index`, `from_address_id` and `to_address_id`
  - `options`: Options for `insert_all`, e.g. `timeout`

  ## Returns
  - The number of stored placeholders
  """
  @spec insert_for_internal_transactions(module(), [map()], Keyword.t()) :: non_neg_integer()
  def insert_for_internal_transactions(repo, internal_transactions, options \\ []) do
    insert_options =
      Keyword.merge(options, on_conflict: add_counts_on_conflict(), conflict_target: [:address_id, :block_number])

    internal_transactions
    |> Enum.group_by(& &1.block_number)
    |> Enum.flat_map(fn {block_number, block_internal_transactions} ->
      block_internal_transactions
      |> Enum.reduce(%{}, fn
        %{index: 0}, acc ->
          acc

        internal_transaction, acc ->
          acc
          |> increment_count(Map.get(internal_transaction, :from_address_id), block_number, :count_froms)
          |> increment_count(Map.get(internal_transaction, :to_address_id), block_number, :count_tos)
      end)
      |> Map.values()
    end)
    # Enforce a stable lock order between concurrent inserts
    |> Enum.sort_by(&{&1.address_id, &1.block_number})
    |> Enum.chunk_every(@insert_batch_size)
    |> Enum.reduce(0, fn batch, count ->
      {inserted_count, _} = repo.insert_all(__MODULE__, batch, insert_options)
      count + inserted_count
    end)
  end

  # The sum is computed as integer: `smallint + smallint` raises on overflow instead of reaching `LEAST`
  defp add_counts_on_conflict do
    from(
      placeholder in __MODULE__,
      update: [
        set: [
          count_tos: fragment("LEAST(?::integer + EXCLUDED.count_tos, ?)", placeholder.count_tos, ^@smallint_max_value),
          count_froms:
            fragment("LEAST(?::integer + EXCLUDED.count_froms, ?)", placeholder.count_froms, ^@smallint_max_value)
        ]
      ]
    )
  end

  @doc """
  Deletes the placeholders of the given blocks, e.g. before the internal transactions of the blocks are processed
  again.

  Does nothing until the index on `block_number` is created by
  `Explorer.Migrator.HeavyDbIndexOperation.CreateDeletedInternalTransactionsAddressPlaceholdersBlockNumberIndex`:
  the primary key starts with `address_id`, so without the index the deletion would scan the whole table.

  ## Parameters
  - `repo`: The repo to delete with
  - `block_numbers`: Numbers of the blocks to delete the placeholders of
  - `options`: Options for `delete_all`, e.g. `timeout`

  ## Returns
  - The number of deleted placeholders
  """
  @spec delete_by_block_numbers(module(), [non_neg_integer()], Keyword.t()) :: non_neg_integer()
  def delete_by_block_numbers(repo, block_numbers, options \\ [])

  def delete_by_block_numbers(_repo, [], _options), do: 0

  def delete_by_block_numbers(repo, block_numbers, options) do
    if block_number_index_ready?() do
      locked_placeholders_query =
        from(
          placeholder in __MODULE__,
          where: placeholder.block_number in ^block_numbers,
          select: %{address_id: placeholder.address_id, block_number: placeholder.block_number},
          # Enforce the lock order of `insert_for_internal_transactions/3`
          order_by: [asc: placeholder.address_id, asc: placeholder.block_number],
          lock: "FOR UPDATE"
        )

      {count, _} =
        repo.delete_all(
          from(
            placeholder in __MODULE__,
            join: locked_placeholder in subquery(locked_placeholders_query),
            on:
              placeholder.address_id == locked_placeholder.address_id and
                placeholder.block_number == locked_placeholder.block_number
          ),
          options
        )

      count
    else
      0
    end
  end

  @doc """
  Returns `true` once `Explorer.Migrator.HeavyDbIndexOperation.CreateDeletedInternalTransactionsAddressPlaceholdersBlockNumberIndex`
  has created the index on `block_number`, so the placeholders can be deleted by block.
  """
  @spec block_number_index_ready?() :: boolean()
  def block_number_index_ready? do
    BackgroundMigrations.get_heavy_indexes_create_deleted_internal_transactions_address_placeholders_block_number_index_finished() ==
      true
  end

  defp increment_count(placeholders, nil, _block_number, _counter), do: placeholders

  defp increment_count(placeholders, address_id, block_number, counter) do
    Map.update(
      placeholders,
      address_id,
      Map.put(%{address_id: address_id, block_number: block_number, count_tos: 0, count_froms: 0}, counter, 1),
      fn placeholder -> Map.update!(placeholder, counter, &min(&1 + 1, @smallint_max_value)) end
    )
  end
end
