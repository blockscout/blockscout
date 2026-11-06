# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.InternalTransactionsAddressPlaceholder do
  @moduledoc """
  Module is responsible for keeping the information about the presence of internal transactions
  on a particular address inside specific block
  """

  use Explorer.Schema

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

  First traces (index 0) are skipped, as they represent the transactions themselves. Existing placeholders of the same
  address and block are replaced.

  ## Parameters
  - `repo`: The repo to insert with
  - `internal_transactions`: Maps with `block_number`, `index`, `from_address_id` and `to_address_id`
  - `options`: Options for `insert_all`, e.g. `timeout`

  ## Returns
  - The number of stored placeholders
  """
  @spec insert_for_internal_transactions(module(), [map()], Keyword.t()) :: non_neg_integer()
  def insert_for_internal_transactions(repo, internal_transactions, options \\ []) do
    insert_options = Keyword.merge(options, on_conflict: :replace_all, conflict_target: [:address_id, :block_number])

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
