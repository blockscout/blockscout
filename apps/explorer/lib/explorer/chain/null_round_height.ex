# SPDX-License-Identifier: LicenseRef-Blockscout
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

  @doc """
    Determines the actual neighboring block numbers of several blocks
    considering null rounds.

    A batch counterpart of `neighbor_block_number/2`: a batch of null rounds
    per given block is fetched with one query in the direction, starting from
    the farthest given block. For a run of consecutive blocks, such as
    a realtime batch, this covers the null rounds between them and beyond.
    Further queries are made only for the blocks whose neighbors lie beyond
    the fetched null rounds.

    ## Parameters
    - `numbers`: The reference block heights
    - `direction`: Either `:previous` or `:next` to indicate search direction

    ## Returns
    - A map from each reference block height to its actual neighboring block
      number.
  """
  @spec neighbor_block_numbers([non_neg_integer()], :previous | :next) :: %{non_neg_integer() => non_neg_integer()}
  def neighbor_block_numbers([], _direction), do: %{}

  def neighbor_block_numbers(numbers, direction) do
    {min_number, max_number} = Enum.min_max(numbers)

    # The fetched null rounds are bounded by the number of blocks rather than by their span
    batch_size = length(numbers) * @null_rounds_batch_size

    # One null round more than the batch size tells whether there are any beyond the batch
    null_rounds =
      case direction do
        :previous -> max_number
        :next -> min_number
      end
      |> neighboring_null_rounds_query(direction, batch_size + 1)
      |> select([nrh], nrh.height)
      |> Repo.all()

    # No more null rounds than the batch size mean there are none beyond the fetched ones
    farthest_fetched = if length(null_rounds) <= batch_size, do: nil, else: List.last(null_rounds)

    null_rounds_set = MapSet.new(null_rounds)

    Map.new(numbers, &{&1, skip_null_rounds(&1, direction, null_rounds_set, farthest_fetched)})
  end

  # Moves from the number in the direction through the fetched null rounds. The null rounds beyond
  # the farthest fetched one are unknown, so they are looked up once the fetched ones are exhausted.
  defp skip_null_rounds(number, direction, null_rounds, farthest_fetched) do
    neighbor = BlockNumberHelper.move_by_one(number, direction)

    cond do
      MapSet.member?(null_rounds, neighbor) -> skip_null_rounds(neighbor, direction, null_rounds, farthest_fetched)
      beyond?(neighbor, farthest_fetched, direction) -> neighbor_block_number(number, direction)
      true -> neighbor
    end
  end

  defp beyond?(_height, nil, _direction), do: false
  defp beyond?(height, farthest_fetched, :previous), do: height < farthest_fetched
  defp beyond?(height, farthest_fetched, :next), do: height > farthest_fetched

  # Constructs a query to fetch neighboring null round heights in batches.
  @spec neighboring_null_rounds_query(non_neg_integer(), :previous | :next, pos_integer()) :: Ecto.Query.t()
  defp neighboring_null_rounds_query(number, direction, batch_size \\ @null_rounds_batch_size)

  defp neighboring_null_rounds_query(number, :previous, batch_size) do
    from(nrh in __MODULE__, where: nrh.height < ^number, order_by: [desc: :height], limit: ^batch_size)
  end

  defp neighboring_null_rounds_query(number, :next, batch_size) do
    from(nrh in __MODULE__, where: nrh.height > ^number, order_by: [asc: :height], limit: ^batch_size)
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
