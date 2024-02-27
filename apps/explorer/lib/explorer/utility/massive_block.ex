defmodule Explorer.Utility.MassiveBlock do
  @moduledoc """
  Module is responsible for keeping the block numbers that are too large for regular import
  and need more time to complete.
  """

  use Explorer.Schema

  alias Explorer.Repo

  schema "massive_blocks" do
    field(:number, :integer)

    timestamps()
  end

  @doc false
  def changeset(massive_block \\ %__MODULE__{}, params) do
    cast(massive_block, params, [:number])
  end

  def get_last_block_number do
    Repo.aggregate(__MODULE__, :max, :number)
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
end
