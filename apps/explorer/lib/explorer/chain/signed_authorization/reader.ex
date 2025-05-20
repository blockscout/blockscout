defmodule Explorer.Chain.SignedAuthorization.Reader do
  @moduledoc """
  Reads signed authorization data from the database.
  """

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Block
  alias Explorer.Repo

  @doc """
  Returns a stream of `Block.t()` for signed authorizations with missing statuses.

  ## Parameters

    - `initial`: The initial accumulator value for the stream.
    - `reducer`: A function that processes each entry in the stream, receiving
      the entry and the current accumulator, and returning a new accumulator.

  ## Returns

    - `{:ok, accumulator}`: The final accumulator value after streaming through
      the block numbers.
  """
  @spec stream_blocks_to_refetch_signed_authorizations_statuses(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_blocks_to_refetch_signed_authorizations_statuses(initial, reducer) when is_function(reducer, 2) do
    query =
      from(
        b in Block,
        join: t in assoc(b, :transactions),
        join: s in assoc(t, :signed_authorizations),
        where: is_nil(s.status) and b.consensus == true,
        distinct: true,
        select: %{
          block_hash: b.hash,
          block_number: b.number
        }
      )

    query |> Repo.stream_reduce(initial, reducer)
  end
end
