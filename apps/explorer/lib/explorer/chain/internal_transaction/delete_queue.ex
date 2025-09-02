defmodule Explorer.Chain.InternalTransaction.DeleteQueue do
  @moduledoc """
  Stores numbers with timestamps for blocks, whose internal transactions should be deleted and refetched
  """

  use Explorer.Schema
  import Ecto.Query
  alias Explorer.Repo

  @primary_key false
  typed_schema "internal_transaction_delete_queue" do
    field(:block_number, :integer, primary_key: true)

    timestamps()
  end

  @spec stream_data(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator),
          threshold :: non_neg_integer()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_data(initial, reducer, threshold \\ 600_000) when is_function(reducer, 2) do
    __MODULE__
    |> where([dq], dq.inserted_at < ago(^threshold, "millisecond"))
    |> order_by([dq], desc: :block_number)
    |> select([dq], dq.block_number)
    |> Repo.stream_reduce(initial, reducer)
  end
end
