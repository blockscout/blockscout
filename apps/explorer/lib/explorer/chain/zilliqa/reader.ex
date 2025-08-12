defmodule Explorer.Chain.Zilliqa.Reader do
  @moduledoc """
  Reads Zilliqa-related data from the database.
  """
  import Explorer.Chain, only: [add_fetcher_limit: 2]
  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.{Address, Transaction}
  alias Explorer.Repo

  @doc """
  Returns a stream of `t:Explorer.Chain.Address.t/0` for Scilla smart contracts
  that should be displayed as verified. The stream yields unverified addresses
  with fetched contract code created by transactions with `v` = `0`.

  ## Parameters

    - `initial`: The initial accumulator value for the stream.
    - `reducer`: A function that processes each entry in the stream, receiving
      the entry and the current accumulator, and returning a new accumulator.
    - `limited?`: A boolean flag to indicate whether the result set should be
      limited. Defaults to `false`.

  ## Returns

    - `{:ok, accumulator}`: The final accumulator value after streaming through
      the unverified Scilla smart contract addresses.
  """
  @spec stream_unverified_scilla_smart_contract_addresses(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unverified_scilla_smart_contract_addresses(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    query =
      from(
        a in Address,
        join: t in Transaction,
        on: a.hash == t.created_contract_address_hash,
        where: t.status == :ok and t.v == 0 and not is_nil(a.contract_code) and a.verified == false,
        order_by: [desc: t.block_number],
        select: a
      )

    query
    |> add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end
end
