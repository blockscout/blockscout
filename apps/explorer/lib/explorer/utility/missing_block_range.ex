defmodule Explorer.Utility.MissingBlockRange do
  @moduledoc """
  Module is responsible for keeping the ranges of blocks that need to be (re)fetched.
  """
  use Explorer.Schema

  alias Explorer.Repo

  @default_returning_batch_size 10

  schema "missing_block_ranges" do
    field(:from_number, :integer)
    field(:to_number, :integer)
  end

  @doc false
  def changeset(range \\ %__MODULE__{}, params) do
    cast(range, params, [:from_number, :to_number])
  end

  def fetch_min_max do
    Repo.one(min_max_block_query())
  end

  def get_latest_batch(size \\ @default_returning_batch_size) do
    size
    |> get_latest_ranges_query()
    |> Repo.all()
    |> Enum.map(fn %{from_number: from, to_number: to} ->
      %Range{first: from, last: to, step: if(from > to, do: -1, else: 1)}
    end)
  end

  def add_ranges_by_block_numbers(numbers) do
    numbers
    |> Enum.map(fn number -> number..number end)
    |> save_batch()
  end

  def clear_batch(batch) do
    Enum.map(batch, fn from..to ->
      __MODULE__
      |> Repo.get_by(from_number: from, to_number: to)
      |> Repo.delete()
    end)
  end

  def save_batch([]), do: {0, nil}

  def save_batch(batch) do
    records =
      batch
      |> List.wrap()
      |> Enum.map(fn from..to -> %{from_number: from, to_number: to} end)

    Repo.insert_all(__MODULE__, records, on_conflict: :nothing, conflict_target: [:from_number, :to_number])
  end

  def min_max_block_query do
    from(r in __MODULE__, select: %{min: min(r.to_number), max: max(r.from_number)})
  end

  def get_latest_ranges_query(size) do
    from(r in __MODULE__, order_by: [desc: r.from_number], limit: ^size)
  end

  def from_number_below_query(lower_bound) do
    from(r in __MODULE__, where: r.from_number < ^lower_bound)
  end

  def to_number_above_query(upper_bound) do
    from(r in __MODULE__, where: r.to_number > ^upper_bound)
  end

  def include_bound_query(bound) do
    from(r in __MODULE__, where: r.from_number > ^bound, where: r.to_number < ^bound)
  end
end
