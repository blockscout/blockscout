defmodule Explorer.Chain.Metrics.Queries do
  @moduledoc """
  Module for DB queries to get chain metrics exposed at /metrics endpoint
  """

  import Ecto.Query,
    only: [
      distinct: 2,
      from: 2,
      join: 4,
      select: 3,
      subquery: 1,
      union: 2,
      where: 3
    ]

  import Explorer.Chain, only: [wrapped_union_subquery: 1]

  alias Explorer.Chain.{
    Address,
    DenormalizationHelper,
    InternalTransaction,
    SmartContract,
    Token,
    TokenTransfer,
    Transaction
  }

  @doc """
  Retrieves the query for fetching the number of successful transactions in a week.
  """
  @spec weekly_success_transactions_number_query() :: Ecto.Query.t()
  def weekly_success_transactions_number_query do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      Transaction
      |> where([transaction], transaction.block_timestamp >= ago(7, "day"))
      |> where([transaction], transaction.status == ^1)
      |> select([transaction], count(transaction.hash))
    else
      Transaction
      |> join(:inner, [transaction], block in assoc(transaction, :block))
      |> where([transaction, block], block.timestamp >= ago(7, "day"))
      |> where([transaction, block], transaction.status == ^1)
      |> select([transaction, block], count(transaction.hash))
    end
  end

  @doc """
  Retrieves the query for the number of smart contracts deployed in the current week.
  """
  @spec weekly_deployed_smart_contracts_number_query() :: Ecto.Query.t()
  def weekly_deployed_smart_contracts_number_query do
    transactions_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        Transaction
        |> where([t], not is_nil(t.created_contract_address_hash))
        |> where([t], t.block_timestamp >= ago(7, "day"))
        |> where([t], t.status == ^1)
        |> select([t], t.created_contract_address_hash)
      else
        Transaction
        |> join(:inner, [t], block in assoc(t, :block))
        |> where([t], not is_nil(t.created_contract_address_hash))
        |> where([t, block], block.timestamp >= ago(7, "day"))
        |> where([t, block], t.status == ^1)
        |> select([t, block], t.created_contract_address_hash)
      end

    internal_transactions_query =
      InternalTransaction
      |> join(:inner, [it], transaction in assoc(it, :transaction))
      |> where([it, t], not is_nil(it.created_contract_address_hash))
      |> where([it, t], t.block_timestamp >= ago(7, "day"))
      |> where([it, t], t.status == ^1)
      |> select([it, t], it.created_contract_address_hash)
      |> wrapped_union_subquery()

    query =
      transactions_query
      |> wrapped_union_subquery()
      |> union(^internal_transactions_query)

    from(
      q in subquery(query),
      select: fragment("COUNT(DISTINCT(?))", q.created_contract_address_hash)
    )
  end

  @doc """
  Retrieves the query for the number of verified smart contracts in the current week.
  """
  @spec weekly_verified_smart_contracts_number_query() :: Ecto.Query.t()
  def weekly_verified_smart_contracts_number_query do
    SmartContract
    |> where([sc], sc.inserted_at >= ago(7, "day"))
    |> select([sc], count(sc.address_hash))
  end

  @doc """
  Retrieves the query for the number of new wallet addresses in the current week.
  """
  @spec weekly_new_wallet_addresses_number_query() :: Ecto.Query.t()
  def weekly_new_wallet_addresses_number_query do
    Address
    |> where([a], a.inserted_at >= ago(7, "day"))
    |> select([a], count(a.hash))
  end

  @doc """
  Retrieves the query for the number of new tokens detected in the current week.
  """
  @spec weekly_new_tokens_number_query() :: Ecto.Query.t()
  def weekly_new_tokens_number_query do
    Token
    |> where([token], token.inserted_at >= ago(7, "day"))
    |> select([token], count(token.contract_address_hash))
  end

  @doc """
  Retrieves the query for the number of new token transfers detected in the current week.
  """
  @spec weekly_new_token_transfers_number_query() :: Ecto.Query.t()
  def weekly_new_token_transfers_number_query do
    TokenTransfer
    |> join(:inner, [tt], block in assoc(tt, :block))
    |> where([tt, block], block.timestamp >= ago(7, "day"))
    |> where([tt, block], block.consensus == true)
    |> select([tt, block], fragment("COUNT(*)"))
  end

  @doc """
  Retrieves the query for the number of active EOA and smart-contract addresses in the current week.
  """
  @spec weekly_active_addresses_number_query() :: Ecto.Query.t()
  def weekly_active_addresses_number_query do
    transactions_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        Transaction
        |> where([t], t.block_timestamp >= ago(7, "day"))
        |> distinct(true)
        |> select([t], %{
          address_hash: fragment("UNNEST(ARRAY[?, ?])", t.from_address_hash, t.to_address_hash)
        })
      else
        Transaction
        |> join(:inner, [t], block in assoc(t, :block))
        |> where([t, block], block.timestamp >= ago(7, "day"))
        |> distinct(true)
        |> select([t, block], %{
          address_hash: fragment("UNNEST(ARRAY[?, ?])", t.from_address_hash, t.to_address_hash)
        })
      end

    from(
      q in subquery(transactions_query),
      select: fragment("COUNT(DISTINCT address_hash)")
    )
  end
end
