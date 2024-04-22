defmodule Explorer.Chain.NullRoundHeight do
  @moduledoc """
  A null round is formed when a block at height N links to a block at height N-2 instead of N-1
  """

  use Explorer.Schema

  alias Explorer.Repo

  @primary_key false
  schema "null_round_heights" do
    field(:height, :integer, primary_key: true)
  end

  def changeset(null_round_height \\ %__MODULE__{}, params) do
    null_round_height
    |> cast(params, [:height])
    |> validate_required([:height])
    |> unique_constraint(:height)
  end

  def total do
    Repo.aggregate(__MODULE__, :count)
  end

  def insert_heights(heights) do
    params =
      heights
      |> Enum.uniq()
      |> Enum.map(&%{height: &1})

    Repo.insert_all(__MODULE__, params, on_conflict: :nothing)
  end

  defp find_neighbor_from_previous(previous_null_rounds, number, direction) do
    previous_null_rounds
    |> Enum.reduce_while({number, nil}, fn height, {current, _result} ->
      if height == move_by_one(current, direction) do
        {:cont, {height, nil}}
      else
        {:halt, {nil, move_by_one(current, direction)}}
      end
    end)
    |> elem(1)
    |> case do
      nil ->
        previous_null_rounds
        |> List.last()
        |> neighbor_block_number(direction)

      number ->
        number
    end
  end

  def neighbor_block_number(number, direction) do
    number
    |> neighbors_query(direction)
    |> select([nrh], nrh.height)
    |> Repo.all()
    |> case do
      [] ->
        move_by_one(number, direction)

      previous_null_rounds ->
        find_neighbor_from_previous(previous_null_rounds, number, direction)
    end
  end

  defp move_by_one(number, :previous), do: number - 1
  defp move_by_one(number, :next), do: number + 1

  @batch_size 5
  defp neighbors_query(number, :previous) do
    from(nrh in __MODULE__, where: nrh.height < ^number, order_by: [desc: :height], limit: @batch_size)
  end

  defp neighbors_query(number, :next) do
    from(nrh in __MODULE__, where: nrh.height > ^number, order_by: [asc: :height], limit: @batch_size)
  end
end
