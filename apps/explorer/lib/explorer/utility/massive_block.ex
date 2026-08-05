# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.MassiveBlock do
  @moduledoc """
  Module is responsible for keeping the block numbers that are too large for regular import
  and need more time to complete.
  """

  use Explorer.Schema

  alias Explorer.Repo

  @primary_key false
  typed_schema "massive_blocks" do
    field(:number, :integer, primary_key: true)

    timestamps()
  end

  @doc false
  def changeset(massive_block \\ %__MODULE__{}, params) do
    cast(massive_block, params, [:number])
  end

  def get_last_block_number(except_numbers) do
    __MODULE__
    |> where([mb], mb.number not in ^except_numbers)
    |> select([mb], max(mb.number))
    |> Repo.one()
  end

  def insert_block_numbers(numbers) do
    now = DateTime.utc_now()
    params = Enum.map(numbers, &%{number: &1, inserted_at: now, updated_at: now})

    Repo.insert_all(__MODULE__, params, on_conflict: {:replace, [:updated_at]}, conflict_target: :number)
  end

  def delete_block_number(number) do
    __MODULE__
    |> where([mb], mb.number == ^number)
    |> Repo.delete_all()
  end

  @doc """
  Deletes the block numbers that don't fall into the given block ranges.

  ## Parameters
  - `ranges`: The list of finite block ranges to keep.
  - `open_range_boundary`: The highest block number that is not covered by the
    trailing `..latest` range, if such a range is configured: every number above
    it is kept. `nil` means that all the configured ranges are finite.

  ## Returns
  - `{deleted_count, nil}`
  """
  @spec delete_numbers_out_of_ranges([Range.t()], non_neg_integer() | nil) :: {non_neg_integer(), nil}
  def delete_numbers_out_of_ranges(ranges, open_range_boundary \\ nil) do
    base_query =
      if is_nil(open_range_boundary),
        do: __MODULE__,
        else: where(__MODULE__, [mb], mb.number <= ^open_range_boundary)

    ranges
    |> Enum.reduce(base_query, fn from..to//_, query ->
      min_number = min(from, to)
      max_number = max(from, to)

      where(query, [mb], mb.number < ^min_number or mb.number > ^max_number)
    end)
    |> Repo.delete_all()
  end
end
