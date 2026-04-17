defmodule Explorer.Chain.InternalTransaction.DeleteQueue do
  @moduledoc """
  Stores numbers for blocks, whose internal transactions should be deleted and refetched
  """

  use Explorer.Schema
  import Ecto.Query
  alias Explorer.Chain.{Block, Import}
  alias Explorer.Repo

  @primary_key false
  typed_schema "internal_transactions_delete_queue" do
    field(:block_number, :integer, primary_key: true)

    timestamps()
  end

  @doc """
  Streams block numbers from the delete queue that are older than the threshold and reduces them using the provided reducer function.

  ## Parameters
  - `initial`: The initial accumulator value
  - `reducer`: A 2-arity function that processes each block number and returns an updated accumulator
  - `threshold`: Time threshold in milliseconds (default: 600_000 ms / 10 minutes). Only entries older than this are streamed

  ## Returns
  - `{:ok, accumulator}`: The final accumulator after processing all entries
  """
  @spec stream_data(
          initial :: accumulator,
          reducer :: (entry :: integer(), accumulator -> accumulator),
          threshold :: non_neg_integer()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_data(initial, reducer, threshold \\ 600_000) when is_function(reducer, 2) do
    __MODULE__
    |> join(:inner, [dq], b in Block, on: dq.block_number == b.number and b.refetch_needed == false)
    |> where([dq], dq.updated_at < ago(^threshold, "millisecond"))
    |> order_by([dq], desc: :block_number)
    |> select([dq], dq.block_number)
    |> distinct(true)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Inserts block numbers into the internal transactions delete queue.

  This function builds queue entries for the given block numbers, adds shared
  insert and update timestamps, and performs a bulk insert. Existing entries are
  ignored because conflicts on the primary key are handled with `:nothing`.

  ## Parameters

    - `block_numbers`: A list of block numbers to enqueue for internal transaction deletion and refetch.

  ## Returns

    - The result of `Repo.safe_insert_all/3`.

  ## Examples

      iex> batch_insert([100, 101, 102])
      {3, nil}

      iex> batch_insert([100, 100])
      {1, nil}

  """
  @spec batch_insert([integer()]) :: {non_neg_integer(), nil | [term()]}
  def batch_insert(block_numbers) do
    timestamps = Import.timestamps()
    params = Enum.map(block_numbers, &Map.put(timestamps, :block_number, &1))

    Repo.safe_insert_all(__MODULE__, params, timeout: :infinity, on_conflict: :nothing)
  end
end
