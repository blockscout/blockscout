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

  alias Explorer.Chain.{Block, BlockNumberHelper}
  alias Explorer.Repo

  @existing_blocks_batch_size 50
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

  # Checks if the given block height represents a null round.
  @spec null_round?(non_neg_integer()) :: boolean()
  defp null_round?(height) do
    query = from(nrh in __MODULE__, where: nrh.height == ^height)
    Repo.exists?(query)
  end

  @doc """
    Finds the next valid block number after checking if the given block is a null round.
    If the block is not a null round, returns the same block number. If it is a null round,
    searches for the next or previous block that exists and is not a null round.

    ## Parameters
    - `block_number`: The block number to check and potentially find next valid block for
    - `direction`: Either `:previous` or `:next` to indicate search direction

    ## Returns
    - `{:ok, number}` where number is either the input block_number or the next valid
      block number
    - `{:error, :not_found}` if no valid next block can be found
  """
  @spec find_next_non_null_round_block(non_neg_integer(), :previous | :next) ::
          {:ok, non_neg_integer()} | {:error, :not_found}
  def find_next_non_null_round_block(block_number, direction) do
    if null_round?(block_number) do
      process_next_batch(block_number, direction)
    else
      {:ok, block_number}
    end
  end

  # Process a batch of blocks starting from the given block number
  @spec process_next_batch(non_neg_integer(), :previous | :next) :: {:ok, non_neg_integer()} | {:error, :not_found}
  defp process_next_batch(block_number, direction) do
    with existing_blocks <- fetch_neighboring_existing_blocks(block_number, direction),
         null_rounds <- fetch_neighboring_null_rounds(block_number, direction) do
      find_first_valid_block(existing_blocks, null_rounds, direction)
    end
  end

  # Fetches the next batch of existing block numbers from the database
  @spec fetch_neighboring_existing_blocks(non_neg_integer(), :previous | :next) :: [non_neg_integer()]
  defp fetch_neighboring_existing_blocks(number, direction) do
    number
    |> neighboring_existing_blocks_query(direction)
    |> select([b], b.number)
    |> Repo.all()
  end

  # Constructs a query to fetch neighboring block numbers in batches
  @spec neighboring_existing_blocks_query(non_neg_integer(), :previous | :next) :: Ecto.Query.t()
  defp neighboring_existing_blocks_query(number, :previous) do
    from(b in Block,
      where: b.number < ^number and b.consensus == true,
      order_by: [desc: b.number],
      limit: @existing_blocks_batch_size
    )
  end

  defp neighboring_existing_blocks_query(number, :next) do
    from(b in Block,
      where: b.number > ^number and b.consensus == true,
      order_by: [asc: b.number],
      limit: @existing_blocks_batch_size
    )
  end

  # Fetches the next batch of null round heights from the database
  @spec fetch_neighboring_null_rounds(non_neg_integer(), :previous | :next) :: [non_neg_integer()]
  defp fetch_neighboring_null_rounds(number, direction) do
    number
    |> neighboring_null_rounds_query(direction)
    |> select([nrh], nrh.height)
    |> Repo.all()
  end

  # Finds the first valid block from the fetched data
  @spec find_first_valid_block([non_neg_integer()], [non_neg_integer()], :previous | :next) ::
          {:ok, non_neg_integer()} | {:error, :not_found}
  defp find_first_valid_block([], _null_rounds, _direction), do: {:error, :not_found}

  defp find_first_valid_block(existing_blocks, null_rounds, direction) do
    null_rounds_set = MapSet.new(null_rounds)

    existing_blocks
    |> Enum.find(fn number ->
      not MapSet.member?(null_rounds_set, number)
    end)
    |> case do
      nil ->
        # If no valid block found in current batch, try the next batch
        last_block_number = List.last(existing_blocks)
        process_next_batch(last_block_number, direction)

      number ->
        {:ok, number}
    end
  end
end
