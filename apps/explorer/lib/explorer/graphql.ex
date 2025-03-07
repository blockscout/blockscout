defmodule Explorer.GraphQL do
  @moduledoc """
  The GraphQL context.
  """

  import Ecto.Query,
    only: [
      from: 2,
      order_by: 3,
      or_where: 3,
      where: 3
    ]

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.{
    Hash,
    InternalTransaction,
    Token,
    TokenTransfer,
    Transaction
  }

  @api_true [api?: true]

  @doc """
  Returns a query to fetch transactions with a matching `to_address_hash`,
  `from_address_hash`, or `created_contract_address_hash` field for a given address hash.

  Orders transactions by `block_number` and `index` according to `order`
  """
  @spec address_to_transactions_query(Hash.Address.t(), :desc | :asc) :: Ecto.Query.t()
  def address_to_transactions_query(address_hash, order) do
    dynamic = Transaction.where_transactions_to_from(address_hash)

    Transaction
    |> where([transaction], ^dynamic)
    |> or_where([transaction], transaction.created_contract_address_hash == ^address_hash)
    |> order_by([transaction], [{^order, transaction.block_number}, {^order, transaction.index}])
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
        where: it.transaction_hash == ^hash
      )

    query
    |> InternalTransaction.where_nonpending_block()
    |> InternalTransaction.where_transaction_has_multiple_internal_transactions()
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
  Returns a token for a given contract address hash.
  """
  @spec get_token(map()) :: {:ok, Token.t()} | {:error, String.t()}
  def get_token(%{contract_address_hash: _} = clauses) do
    if token = Repo.replica().get_by(Token, clauses) do
      {:ok, token}
    else
      {:error, "Token not found."}
    end
  end

  @doc """
  Returns a transaction for a given hash.
  """
  @spec get_transaction_by_hash(Hash.t()) :: {:ok, Transaction.t()} | {:error, String.t()}
  def get_transaction_by_hash(hash) do
    hash
    |> Chain.hash_to_transaction(@api_true)
    |> case do
      {:ok, _} = result -> result
      {:error, :not_found} -> {:error, "Transaction not found."}
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
      order_by: [desc: tt.block_number, desc: tt.log_index]
    )
  end
end
