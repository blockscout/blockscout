defmodule Explorer.Chain.Transaction.Reader do
  @moduledoc """
  Functions for reading transaction data.
  """
  import Ecto.Query
  import Explorer.Chain, only: [add_fetcher_limit: 2]

  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @doc """
  Determines if a transaction has created a smart contract whose code has not
  yet been indexed.

  ## Parameters
  - `transaction`: A `t:Explorer.Chain.Transaction.t/0` struct to be examined

  ## Returns
  - `true` when the transaction meets all of the following conditions:
    - Is included in a block
    - Has created a contract
    - Has not had its contract code indexed
  - `false` otherwise
  """
  @spec transaction_with_unfetched_created_contract_code?(transaction :: Transaction.t()) :: boolean()
  def transaction_with_unfetched_created_contract_code?(transaction) do
    not is_nil(transaction.block_hash) and
      not is_nil(transaction.created_contract_address_hash) and
      is_nil(transaction.created_contract_code_indexed_at)
  end

  @doc """
  Streams transactions that have created contracts whose code has not yet been
  indexed.

  This function allows processing transactions in a memory-efficient way by
  streaming them through a reducer function.

  ## Parameters
  - `fields`: A list of fields to select from the transactions.
  - `initial`: The initial accumulator value to use with the reducer.
  - `reducer`: A function that takes each transaction entry and the current
    accumulator, and returns the new accumulator value.
  - `limited?`: A boolean flag indicating whether to limit the number of results
    (default: `false`).

  ## Returns
  - `{:ok, accumulator}` where `accumulator` is the final value after all
    transactions have been processed through the reducer function.
  """
  @spec stream_transactions_with_unfetched_created_contract_code(
          fields :: [
            :block_hash
            | :created_contract_code_indexed_at
            | :from_address_hash
            | :gas
            | :gas_price
            | :hash
            | :index
            | :input
            | :nonce
            | :r
            | :s
            | :to_address_hash
            | :v
            | :value
          ],
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_transactions_with_unfetched_created_contract_code(fields, initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    query =
      from(t in Transaction,
        where:
          not is_nil(t.block_hash) and not is_nil(t.created_contract_address_hash) and
            is_nil(t.created_contract_code_indexed_at),
        select: ^fields
      )

    query
    |> add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end
end
