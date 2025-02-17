defmodule Explorer.Chain.NullRoundHeight do
  @moduledoc """
  Manages and tracks null round heights in the Filecoin blockchain.

  A null round in Filecoin occurs when no miner successfully wins the leader election
  for a particular epoch, resulting in no block production. When this happens, the
  next successful block links to the last valid block, creating a gap in block
  heights. For example, if block at height 100 links to block at height 98, height
  99 represents a null round.

  ## Example

      # Insert multiple null round heights
      NullRoundHeight.insert_heights([100, 102, 105])

      # Find the actual next block number considering null rounds
      NullRoundHeight.neighbor_block_number(99, :next)
      # Returns 101 if 100 is a null round

      # Get total count of null rounds
      NullRoundHeight.total()
  """

  use Explorer.Schema

  alias Explorer.Chain.BlockNumberHelper
  alias Explorer.Repo

  @null_rounds_batch_size 5

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

  @doc """
    Returns the total count of null rounds recorded in the database.

    ## Returns
    - The total number of null round heights stored in the database.
  """
  @spec total() :: non_neg_integer()
  def total do
    Repo.aggregate(__MODULE__, :count)
  end

  @doc """
    Inserts multiple null round heights into the database while preventing duplicates.

    The function processes the input list by removing duplicates and transforming heights
    into the required map structure before performing a bulk insert operation.

    ## Parameters
    - `heights`: List of block heights representing null rounds to be recorded.

    ## Returns
    - The number of null round heights successfully inserted.
  """
  @spec insert_heights([non_neg_integer()]) :: {non_neg_integer(), nil | [term()]}
  def insert_heights(heights) do
    params =
      heights
      |> Enum.uniq()
      |> Enum.map(&%{height: &1})

    Repo.insert_all(__MODULE__, params, on_conflict: :nothing)
  end

  # Finds the neighboring block number in a sequence of null rounds.
  #
  # Analyzes a batch of previous null rounds to determine the actual neighboring block number,
  # taking into account consecutive null rounds.
  #
  # ## Parameters
  # - `previous_null_rounds`: List of null round heights to analyze
  # - `number`: The reference block height
  # - `direction`: Either `:previous` or `:next` to indicate search direction
  #
  # ## Returns
  # - The neighboring block number considering the sequence of null rounds
  @spec find_neighbor_from_previous(list(non_neg_integer()), non_neg_integer(), :previous | :next) :: non_neg_integer()
  defp find_neighbor_from_previous(previous_null_rounds, number, direction) do
    previous_null_rounds
    |> Enum.reduce_while({number, nil}, fn height, {current, _result} ->
      if height == BlockNumberHelper.move_by_one(current, direction) do
        {:cont, {height, nil}}
      else
        {:halt, {nil, BlockNumberHelper.move_by_one(current, direction)}}
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

  @doc """
    Determines the actual neighboring block number considering null rounds.

    When traversing the blockchain, this function helps navigate through null rounds
    to find the actual previous or next block number. It accounts for consecutive
    null rounds by querying the database in batches.

    ## Parameters
    - `number`: The reference block height
    - `direction`: Either `:previous` or `:next` to indicate search direction

    ## Returns
    - The actual neighboring block number, accounting for any null rounds
  """
  @spec neighbor_block_number(non_neg_integer(), :previous | :next) :: non_neg_integer()
  def neighbor_block_number(number, direction) do
    case fetch_neighboring_null_rounds(number, direction) do
      [] ->
        BlockNumberHelper.move_by_one(number, direction)

      previous_null_rounds ->
        find_neighbor_from_previous(previous_null_rounds, number, direction)
    end
  end

  # Constructs a query to fetch neighboring null round heights in batches.
  @spec neighboring_null_rounds_query(non_neg_integer(), :previous | :next) :: Ecto.Query.t()
  defp neighboring_null_rounds_query(number, :previous) do
    from(nrh in __MODULE__, where: nrh.height < ^number, order_by: [desc: :height], limit: @null_rounds_batch_size)
  end

  defp neighboring_null_rounds_query(number, :next) do
    from(nrh in __MODULE__, where: nrh.height > ^number, order_by: [asc: :height], limit: @null_rounds_batch_size)
  end

  # Fetches the next batch of null round heights from the database
  @spec fetch_neighboring_null_rounds(non_neg_integer(), :previous | :next) :: [non_neg_integer()]
  defp fetch_neighboring_null_rounds(number, direction) do
    number
    |> neighboring_null_rounds_query(direction)
    |> select([nrh], nrh.height)
    |> Repo.all()
  end
end
