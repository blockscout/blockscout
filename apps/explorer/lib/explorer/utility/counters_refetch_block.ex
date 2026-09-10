# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.CountersRefetchBlock do
  @moduledoc """
  Keeps block numbers whose old content was already subtracted from the
  incremental counters (the address counters `addresses.transactions_count`,
  `addresses.token_transfers_count`, `addresses.gas_used` and the token
  counter `tokens.transfer_count`) because the blocks were queued for re-fetch
  (see `Explorer.Chain.Block.full_refetch/1`).

  A row means "the negative counters deltas for this block were applied, the
  positive deltas from its re-imported content are still pending". Rows are
  consumed by `Explorer.Chain.Cache.Counters.Consolidation.settle_pending_refetch_blocks/0`
  once the corresponding block no longer requires a re-fetch. While a row
  exists, no consolidation watermark (address or token) advances past this
  block number.
  """

  use Explorer.Schema

  alias Explorer.Repo

  @primary_key false
  typed_schema "counters_refetch_blocks" do
    field(:block_number, :integer, primary_key: true)

    timestamps()
  end

  @doc false
  def changeset(refetch_block \\ %__MODULE__{}, params) do
    cast(refetch_block, params, [:block_number])
  end

  @doc """
  Returns the minimum pending block number or `nil` when the table is empty.
  """
  @spec min_block_number() :: non_neg_integer() | nil
  def min_block_number do
    __MODULE__
    |> select([r], min(r.block_number))
    |> Repo.one()
  end

  @doc """
  Deletes the rows for the given block numbers.
  """
  @spec delete_by_block_numbers([non_neg_integer()]) :: {non_neg_integer(), nil}
  def delete_by_block_numbers(block_numbers) do
    __MODULE__
    |> where([r], r.block_number in ^block_numbers)
    |> Repo.delete_all()
  end
end
