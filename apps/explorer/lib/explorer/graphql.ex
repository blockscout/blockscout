defmodule Explorer.GraphQL do
  @moduledoc """
  The GraphQL context.
  """

  import Ecto.Query,
    only: [
      subquery: 1,
      from: 2,
      fragment: 3,
      order_by: 3,
      or_where: 3,
      where: 3
    ]

  alias Explorer.Chain.{
    Hash,
    InternalTransaction,
    TokenTransfer,
    Transaction
  }

  alias Explorer.{Chain, Repo}

  @doc """
  Returns a query to fetch transactions with a matching `to_address_hash`,
  `from_address_hash`, or `created_contract_address_hash` field for a given address hash.

  Orders transactions by descending block number and index.
  """
  @spec address_to_transactions_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_to_transactions_query(address_hash) do
    ordered_query = Transaction
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
    |> where([transaction], transaction.to_address_hash == ^address_hash)
    |> or_where([transaction], transaction.from_address_hash == ^address_hash)
    |> or_where([transaction], transaction.created_contract_address_hash == ^address_hash)

    # When using a cursor to iterate over the results of a query, it's possible that either a new block gets created or that a rollback happens
    # this is problematic for pagination because the default cursor for absinthe is simply an offset in the SQL query
    # this means that:
    # - In the case of a new block (if you're using desc order), you will see the same transaction twice
    # - In the case of a rollback, (if you're using desc order), you may skip a transcation (and not realize some of your prev fetched data is now incorrect)
    # In order for programs paginating over results to fail-fast if the result is changing mid-iteration, we override the default cursor to contain CSV(offset, block_hash, tx_hash)
    # This ensures that if the ordering changes, one (or both) of block_hash & tx_hash will no longer match so you'll get an error
    #
    # to avoid SQL injection, using a dynamic string for `fragment` is disallowed, so we instead inline this ugly string
    # here is the explanation of each step:
    # 1) Represent the offset as `'arrayconnection:', ROW_NUMBER () over () - 1`
    #    This is done because absinthe requires the offset to contain `arrayconnection:` as a prefix
    #    We use `ROW_NUMBER() over ()` to get the index of the row in the SQL output
    #    We offset by `-1` because SQL rows are 1-indexed, but cursors are 0-indexed
    #    Note: we're using `subquery` here because `SELECT` runs before `ORDER BY` in SQL
    #          but we want to get the `ROW_NUMBER` after we formed `ordered_query`
    #          the easiest way to do this is to wrap `ordered_query` into a new query so we can perform the `SELECT` after the `ORDER BY`
    # 2) `CONCAT` <offset, block_hash, tx_hash>
    # 3) `ENCODE` as base64 by going from string -> `convert_to` utf-8 bytes -> base64
    #    This is required because absinthe expects cursors to be base64 encoded
    # 4) `translate` to remove any \n newlines added by postgres
    #    This is required because postgres splits up base64 strings in lines of 76 chars by default
    subquery(ordered_query) |> select([transaction], {transaction, cursor: fragment("translate(ENCODE(convert_to(CONCAT('arrayconnection:', ROW_NUMBER () over () - 1, ',', encode(?, 'hex'), ',', encode(?, 'hex')), 'utf-8'), 'base64'), E'\n', '')", transaction.block_hash, transaction.hash)})
  end

  @doc """
  Returns an internal transaction for a given transaction hash and index.
  """
  @spec get_internal_transaction(map()) :: {:ok, InternalTransaction.t()} | {:error, String.t()}
  def get_internal_transaction(%{transaction_hash: _, index: _} = clauses) do
    if internal_transaction = Repo.replica().get_by(InternalTransaction.where_nonpending_block(), clauses) do
      {:ok, internal_transaction}
    else
      {:error, "Internal transaction not found."}
    end
  end

  @doc """
  Returns a query to fetch internal transactions for a given transaction.

  Orders internal transactions by ascending index.
  """
  @spec transaction_to_internal_transactions_query(Transaction.t()) :: Ecto.Query.t()
  def transaction_to_internal_transactions_query(%Transaction{
        hash: %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash
      }) do
    query =
      from(
        it in InternalTransaction,
        inner_join: t in assoc(it, :transaction),
        order_by: [asc: it.index],
        where: it.transaction_hash == ^hash,
        select: it
      )

    query
    |> InternalTransaction.where_nonpending_block()
    |> Chain.where_transaction_has_multiple_internal_transactions()
  end

  @doc """
  Returns a token transfer for a given transaction hash and log index.
  """
  @spec get_token_transfer(map()) :: {:ok, TokenTransfer.t()} | {:error, String.t()}
  def get_token_transfer(%{transaction_hash: _, log_index: _} = clauses) do
    if token_transfer = Repo.replica().get_by(TokenTransfer, clauses) do
      {:ok, token_transfer}
    else
      {:error, "Token transfer not found."}
    end
  end

  @doc """
  Returns a query to fetch token transfers for a token contract address hash.

  Orders token transfers by descending block number.
  """
  @spec list_token_transfers_query(Hash.t()) :: Ecto.Query.t()
  def list_token_transfers_query(%Hash{byte_count: unquote(Hash.Address.byte_count())} = token_contract_address_hash) do
    from(
      tt in TokenTransfer,
      inner_join: t in assoc(tt, :transaction),
      where: tt.token_contract_address_hash == ^token_contract_address_hash,
      order_by: [desc: tt.block_number],
      select: tt
    )
  end
end
