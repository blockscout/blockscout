defmodule Explorer.Chain.InternalTransaction.DeleteQueue do
  @moduledoc """
  Stores numbers for blocks, whose internal transactions should be deleted and refetched
  """

  use Explorer.Schema
  import Ecto.Query
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
    |> where([dq], dq.updated_at < ago(^threshold, "millisecond"))
    |> order_by([dq], desc: :block_number)
    |> select([dq], dq.block_number)
    |> Repo.stream_reduce(initial, reducer)
  end
end
