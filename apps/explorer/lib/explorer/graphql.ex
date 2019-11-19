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

  import Ecto.Query.API,
    only: [
      fragment: 1
    ]

  alias Explorer.Chain.{
    Hash,
    InternalTransaction,
    TokenTransfer,
    Transaction,
    CeloAccount,
    Address
  }

  alias Explorer.{Chain, Repo}

  @doc """
  Returns a query to fetch transactions with a matching `to_address_hash`,
  `from_address_hash`, or `created_contract_address_hash` field for a given address hash.

  Orders transactions by descending block number and index.
  """
  @spec address_to_transactions_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_to_transactions_query(address_hash) do
    Transaction
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
    |> where([transaction], transaction.to_address_hash == ^address_hash)
    |> or_where([transaction], transaction.from_address_hash == ^address_hash)
    |> or_where([transaction], transaction.created_contract_address_hash == ^address_hash)
  end

  def address_to_account_query(address_hash) do
    CeloAccount
    |> where([account], account.address == ^address_hash)
  end

  def address_query(address_hash) do
    Address
    |> where([account], account.hash == ^address_hash)
  end

  def leaderboard_query do
    fragment("""
      SELECT competitors.address, SUM(rate*value+fetched_coin_balance+locked_gold)*multiplier AS score
      FROM addresses, exchange_rates, competitors, claims, celo_account,
        (SELECT claims.claim_address AS address, COALESCE(SUM(value),0) AS value
         FROM address_current_token_balances, claims
         WHERE address_hash=claims.claim_address
         AND token_contract_address_hash='\\x88f24de331525cf6cfd7455eb96a9e4d49b7f292'
         GROUP BY claims.claim_address) AS get
      WHERE  token='\\x88f24de331525cf6cfd7455eb96a9e4d49b7f292'
      AND claims.claim_address = get.address
      AND celo_account.address = addresses.hash
      AND claims.address = competitors.address
      GROUP BY competitors.address
      ORDER BY score
    """)
  end

  @doc """
  Returns an internal transaction for a given transaction hash and index.
  """
  @spec get_internal_transaction(map()) :: {:ok, InternalTransaction.t()} | {:error, String.t()}
  def get_internal_transaction(%{transaction_hash: _, index: _} = clauses) do
    if internal_transaction = Repo.get_by(InternalTransaction, clauses) do
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

    Chain.where_transaction_has_multiple_internal_transactions(query)
  end

  @doc """
  Returns a token transfer for a given transaction hash and log index.
  """
  @spec get_token_transfer(map()) :: {:ok, TokenTransfer.t()} | {:error, String.t()}
  def get_token_transfer(%{transaction_hash: _, log_index: _} = clauses) do
    if token_transfer = Repo.get_by(TokenTransfer, clauses) do
      {:ok, token_transfer}
    else
      {:error, "Token transfer not found."}
    end
  end

  @doc """
  Returns a query to fetch token transfers for a token contract address hash.

  Orders token transfers by descending block number, descending transaction index, and ascending log index.
  """
  @spec list_token_transfers_query(Hash.t()) :: Ecto.Query.t()
  def list_token_transfers_query(%Hash{byte_count: unquote(Hash.Address.byte_count())} = token_contract_address_hash) do
    from(
      tt in TokenTransfer,
      inner_join: t in assoc(tt, :transaction),
      where: tt.token_contract_address_hash == ^token_contract_address_hash,
      order_by: [desc: tt.block_number, desc: t.index, asc: tt.log_index],
      select: tt
    )
  end
end
