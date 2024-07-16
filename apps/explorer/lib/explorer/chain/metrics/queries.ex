defmodule Explorer.Chain.Metrics.Queries do
  @moduledoc """
  Module for DB queries to get chain metrics exposed at /metrics endpoint
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
  @spec weekly_success_transactions_number_query() :: Ecto.Query.t()
  def weekly_success_transactions_number_query do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      Transaction
      |> where([tx], tx.block_timestamp >= ago(7, "day"))
      |> where([tx], tx.block_consensus == true)
      |> where([tx], tx.status == ^1)
      |> select([tx], count(tx.hash))
    else
      Transaction
      |> join(:inner, [tx], block in assoc(tx, :block))
      |> where([tx, block], block.timestamp >= ago(7, "day"))
      |> where([tx, block], block.consensus == true)
      |> where([tx, block], tx.status == ^1)
      |> select([tx, block], count(tx.hash))
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
        |> where([tx], not is_nil(tx.created_contract_address_hash))
        |> where([tx], tx.block_timestamp >= ago(7, "day"))
        |> where([tx], tx.block_consensus == true)
        |> where([tx], tx.status == ^1)
        |> select([tx], tx.created_contract_address_hash)
      else
        Transaction
        |> join(:inner, [tx], block in assoc(tx, :block))
        |> where([tx], not is_nil(tx.created_contract_address_hash))
        |> where([tx, block], block.consensus == true)
        |> where([tx, block], block.timestamp >= ago(7, "day"))
        |> where([tx, block], tx.status == ^1)
        |> select([tx, block], tx.created_contract_address_hash)
      end

    # todo: this part is too slow, need to optimize
    # internal_transactions_query =
    #   InternalTransaction
    #   |> join(:inner, [it], transaction in assoc(it, :transaction))
    #   |> where([it, tx], not is_nil(it.created_contract_address_hash))
    #   |> where([it, tx], tx.block_timestamp >= ago(7, "day"))
    #   |> where([it, tx], tx.block_consensus == true)
    #   |> where([it, tx], tx.status == ^1)
    #   |> select([it, tx], it.created_contract_address_hash)
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
  @spec weekly_verified_smart_contracts_number_query() :: Ecto.Query.t()
  def weekly_verified_smart_contracts_number_query do
    SmartContract
    |> where([sc], sc.inserted_at >= ago(7, "day"))
    |> select([sc], count(sc.address_hash))
  end

  @doc """
  Retrieves the query for the number of new addresses in the current week.
  """
  @spec weekly_new_addresses_number_query() :: Ecto.Query.t()
  def weekly_new_addresses_number_query do
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
    |> join(:inner, [tt], block in Block, on: block.number == tt.block_number)
    |> where([tt, block], block.timestamp >= ago(7, "day"))
    |> where([tt, block], block.consensus == true)
    |> select([tt, block], fragment("COUNT(*)"))
  end

  @doc """
  Retrieves the query for the number of addresses initiated transactions in the current week.
  """
  @spec weekly_simplified_active_addresses_number_query() :: Ecto.Query.t()
  def weekly_simplified_active_addresses_number_query do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      Transaction
      |> where([tx], tx.block_timestamp >= ago(7, "day"))
      |> where([tx], tx.block_consensus == true)
      |> select([tx], fragment("COUNT(DISTINCT(?))", tx.from_address_hash))
    else
      Transaction
      |> join(:inner, [tx], block in assoc(tx, :block))
      |> where([tx, block], block.timestamp >= ago(7, "day"))
      |> where([tx, block], block.consensus == true)
      |> select([tx], fragment("COUNT(DISTINCT(?))", tx.from_address_hash))
    end
  end

  @doc """
  Retrieves the query for the number of active EOA and smart-contract addresses (from/to/contract participated in transactions, internal transactions, token transfers) in the current week.
  This query is currently unused since the very low performance: it doesn't return results in 1 hour.
  """
  @spec weekly_active_addresses_number_query() :: Ecto.Query.t()
  def weekly_active_addresses_number_query do
    transactions_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        Transaction
        |> where([tx], tx.block_timestamp >= ago(7, "day"))
        |> where([tx], tx.block_consensus == true)
        |> distinct(true)
        |> select([tx], %{
          address_hash:
            fragment(
              "UNNEST(ARRAY[?, ?, ?])",
              tx.from_address_hash,
              tx.to_address_hash,
              tx.created_contract_address_hash
            )
        })
      else
        Transaction
        |> join(:inner, [tx], block in assoc(tx, :block))
        |> where([tx, block], block.timestamp >= ago(7, "day"))
        |> where([tx, block], block.consensus == true)
        |> distinct(true)
        |> select([tx, block], %{
          address_hash:
            fragment(
              "UNNEST(ARRAY[?, ?, ?])",
              tx.from_address_hash,
              tx.to_address_hash,
              tx.created_contract_address_hash
            )
        })
      end

    internal_transactions_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        InternalTransaction
        |> join(:inner, [it], transaction in assoc(it, :transaction))
        |> where([it, tx], tx.block_timestamp >= ago(7, "day"))
        |> where([it, tx], tx.block_consensus == true)
        |> where([it, tx], tx.status == ^1)
        |> select([it, tx], %{
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
        |> join(:inner, [tx], block in assoc(tx, :block))
        |> where([it, tx, block], tx.block_timestamp >= ago(7, "day"))
        |> where([it, tx, block], block.consensus == true)
        |> where([it, tx, block], tx.status == ^1)
        |> select([it, tx, block], %{
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
        |> where([tt, tx], tx.block_timestamp >= ago(7, "day"))
        |> where([tt, tx], tx.block_consensus == true)
        |> where([tt, tx], tx.status == ^1)
        |> select([tt, tx], %{
          address_hash:
            fragment("UNNEST(ARRAY[?, ?, ?])", tt.from_address_hash, tt.to_address_hash, tt.token_contract_address_hash)
        })
        |> wrapped_union_subquery()
      else
        TokenTransfer
        |> join(:inner, [tt], transaction in assoc(tt, :transaction))
        |> join(:inner, [tx], block in assoc(tx, :block))
        |> where([tt, tx, block], tx.block_timestamp >= ago(7, "day"))
        |> where([tt, tx, block], block.consensus == true)
        |> where([tt, tx, block], tx.status == ^1)
        |> select([tt, tx, block], %{
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
end
