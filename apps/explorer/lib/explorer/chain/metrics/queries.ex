defmodule Explorer.Chain.Metrics.Queries do
  @moduledoc """
  Module for DB queries to get chain metrics exposed at /public-metrics endpoint
  """

  import Ecto.Query,
    only: [
      distinct: 2,
      from: 2,
      join: 4,
      join: 5,
      select: 3,
      subquery: 1,
      union: 2,
      where: 3
    ]

  import Explorer.Chain, only: [wrapped_union_subquery: 1]

  alias Explorer.Chain.{
    Address,
    Block,
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
  @spec success_transactions_number_query() :: Ecto.Query.t()
  def success_transactions_number_query do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      Transaction
      |> where([transaction], transaction.block_timestamp >= ago(^update_period_hours(), "hour"))
      |> where([transaction], transaction.block_consensus == true)
      |> where([transaction], transaction.status == ^1)
      |> select([transaction], count(transaction.hash))
    else
      Transaction
      |> join(:inner, [transaction], block in assoc(transaction, :block))
      |> where([transaction, block], block.timestamp >= ago(^update_period_hours(), "hour"))
      |> where([transaction, block], block.consensus == true)
      |> where([transaction, block], transaction.status == ^1)
      |> select([transaction, block], count(transaction.hash))
    end
  end

  @doc """
  Retrieves the query for the number of smart contracts deployed in the current week.
  """
  @spec deployed_smart_contracts_number_query() :: Ecto.Query.t()
  def deployed_smart_contracts_number_query do
    transactions_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        Transaction
        |> where([transaction], not is_nil(transaction.created_contract_address_hash))
        |> where([transaction], transaction.block_timestamp >= ago(^update_period_hours(), "hour"))
        |> where([transaction], transaction.block_consensus == true)
        |> where([transaction], transaction.status == ^1)
        |> select([transaction], transaction.created_contract_address_hash)
      else
        Transaction
        |> join(:inner, [transaction], block in assoc(transaction, :block))
        |> where([transaction], not is_nil(transaction.created_contract_address_hash))
        |> where([transaction, block], block.consensus == true)
        |> where([transaction, block], block.timestamp >= ago(^update_period_hours(), "hour"))
        |> where([transaction, block], transaction.status == ^1)
        |> select([transaction, block], transaction.created_contract_address_hash)
      end

    # todo: this part is too slow, need to optimize
    # internal_transactions_query =
    #   InternalTransaction
    #   |> join(:inner, [it], transaction in assoc(it, :transaction))
    #   |> where([it, transaction], not is_nil(it.created_contract_address_hash))
    #   |> where([it, transaction], transaction.block_timestamp >= ago(^update_period_hours(), "hour"))
    #   |> where([it, transaction], transaction.block_consensus == true)
    #   |> where([it, transaction], transaction.status == ^1)
    #   |> select([it, transaction], it.created_contract_address_hash)
    #   |> wrapped_union_subquery()

    # query =
    #   transactions_query
    #   |> wrapped_union_subquery()
    #   |> union(^internal_transactions_query)

    from(
      q in subquery(transactions_query),
      select: fragment("COUNT(DISTINCT(?))", q.created_contract_address_hash)
    )
  end

  @doc """
  Retrieves the query for the number of verified smart contracts in the current week.
  """
  @spec verified_smart_contracts_number_query() :: Ecto.Query.t()
  def verified_smart_contracts_number_query do
    SmartContract
    |> where([sc], sc.inserted_at >= ago(^update_period_hours(), "hour"))
    |> select([sc], count(sc.address_hash))
  end

  @doc """
  Retrieves the query for the number of new addresses in the current week.
  """
  @spec new_addresses_number_query() :: Ecto.Query.t()
  def new_addresses_number_query do
    Address
    |> where([a], a.inserted_at >= ago(^update_period_hours(), "hour"))
    |> select([a], count(a.hash))
  end

  @doc """
  Retrieves the query for the number of new tokens detected in the current week.
  """
  @spec new_tokens_number_query() :: Ecto.Query.t()
  def new_tokens_number_query do
    Token
    |> where([token], token.inserted_at >= ago(^update_period_hours(), "hour"))
    |> select([token], count(token.contract_address_hash))
  end

  @doc """
  Retrieves the query for the number of new token transfers detected in the current week.
  """
  @spec new_token_transfers_number_query() :: Ecto.Query.t()
  def new_token_transfers_number_query do
    TokenTransfer
    |> join(:inner, [tt], block in Block, on: block.number == tt.block_number)
    |> where([tt, block], block.timestamp >= ago(^update_period_hours(), "hour"))
    |> where([tt, block], block.consensus == true)
    |> select([tt, block], fragment("COUNT(*)"))
  end

  @doc """
  Retrieves the query for the number of addresses initiated transactions in the current week.
  """
  @spec simplified_active_addresses_number_query() :: Ecto.Query.t()
  def simplified_active_addresses_number_query do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      Transaction
      |> where([transaction], transaction.block_timestamp >= ago(^update_period_hours(), "hour"))
      |> where([transaction], transaction.block_consensus == true)
      |> select([transaction], fragment("COUNT(DISTINCT(?))", transaction.from_address_hash))
    else
      Transaction
      |> join(:inner, [transaction], block in assoc(transaction, :block))
      |> where([transaction, block], block.timestamp >= ago(^update_period_hours(), "hour"))
      |> where([transaction, block], block.consensus == true)
      |> select([transaction], fragment("COUNT(DISTINCT(?))", transaction.from_address_hash))
    end
  end

  @doc """
  Retrieves the query for the number of active EOA and smart-contract addresses (from/to/contract participated in transactions, internal transactions, token transfers) in the current week.
  This query is currently unused since the very low performance: it doesn't return results in 1 hour.
  """
  @spec active_addresses_number_query() :: Ecto.Query.t()
  def active_addresses_number_query do
    transactions_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        Transaction
        |> where([transaction], transaction.block_timestamp >= ago(^update_period_hours(), "hour"))
        |> where([transaction], transaction.block_consensus == true)
        |> distinct(true)
        |> select([transaction], %{
          address_hash:
            fragment(
              "UNNEST(ARRAY[?, ?, ?])",
              transaction.from_address_hash,
              transaction.to_address_hash,
              transaction.created_contract_address_hash
            )
        })
      else
        Transaction
        |> join(:inner, [transaction], block in assoc(transaction, :block))
        |> where([transaction, block], block.timestamp >= ago(^update_period_hours(), "hour"))
        |> where([transaction, block], block.consensus == true)
        |> distinct(true)
        |> select([transaction, block], %{
          address_hash:
            fragment(
              "UNNEST(ARRAY[?, ?, ?])",
              transaction.from_address_hash,
              transaction.to_address_hash,
              transaction.created_contract_address_hash
            )
        })
      end

    internal_transactions_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        InternalTransaction
        |> join(:inner, [it], transaction in assoc(it, :transaction))
        |> where([it, transaction], transaction.block_timestamp >= ago(^update_period_hours(), "hour"))
        |> where([it, transaction], transaction.block_consensus == true)
        |> where([it, transaction], transaction.status == ^1)
        |> select([it, transaction], %{
          address_hash:
            fragment(
              "UNNEST(ARRAY[?, ?, ?])",
              it.from_address_hash,
              it.to_address_hash,
              it.created_contract_address_hash
            )
        })
        |> wrapped_union_subquery()
      else
        InternalTransaction
        |> join(:inner, [it], transaction in assoc(it, :transaction))
        |> join(:inner, [transaction], block in assoc(transaction, :block))
        |> where([it, transaction, block], transaction.block_timestamp >= ago(^update_period_hours(), "hour"))
        |> where([it, transaction, block], block.consensus == true)
        |> where([it, transaction, block], transaction.status == ^1)
        |> select([it, transaction, block], %{
          address_hash:
            fragment(
              "UNNEST(ARRAY[?, ?, ?])",
              it.from_address_hash,
              it.to_address_hash,
              it.created_contract_address_hash
            )
        })
        |> wrapped_union_subquery()
      end

    token_transfers_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        TokenTransfer
        |> join(:inner, [tt], transaction in assoc(tt, :transaction))
        |> where([tt, transaction], transaction.block_timestamp >= ago(^update_period_hours(), "hour"))
        |> where([tt, transaction], transaction.block_consensus == true)
        |> where([tt, transaction], transaction.status == ^1)
        |> select([tt, transaction], %{
          address_hash:
            fragment("UNNEST(ARRAY[?, ?, ?])", tt.from_address_hash, tt.to_address_hash, tt.token_contract_address_hash)
        })
        |> wrapped_union_subquery()
      else
        TokenTransfer
        |> join(:inner, [tt], transaction in assoc(tt, :transaction))
        |> join(:inner, [transaction], block in assoc(transaction, :block))
        |> where([tt, transaction, block], transaction.block_timestamp >= ago(^update_period_hours(), "hour"))
        |> where([tt, transaction, block], block.consensus == true)
        |> where([tt, transaction, block], transaction.status == ^1)
        |> select([tt, transaction, block], %{
          address_hash:
            fragment("UNNEST(ARRAY[?, ?, ?])", tt.from_address_hash, tt.to_address_hash, tt.token_contract_address_hash)
        })
        |> wrapped_union_subquery()
      end

    query =
      transactions_query
      |> wrapped_union_subquery()
      |> union(^internal_transactions_query)
      |> union(^token_transfers_query)

    from(
      q in subquery(query),
      select: fragment("COUNT(DISTINCT ?)", q.address_hash)
    )
  end

  defp update_period_hours do
    Application.get_env(:explorer, Explorer.Chain.Metrics)[:update_period_hours]
  end
end
