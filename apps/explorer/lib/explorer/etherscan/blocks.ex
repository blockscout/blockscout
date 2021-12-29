defmodule Explorer.Etherscan.Blocks do
  @moduledoc """
  This module contains functions for working with blocks, as they pertain to the
  `Explorer.Etherscan` context.

  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address.CoinBalance, Block, Hash, Wei}

  @doc """
  Returns the balance of the given address and block combination.

  Returns `{:error, :not_found}` if there is no address by that hash present.
  Returns `{:error, :no_balance}` if there is no balance for that address at that block.
  """
  @spec get_balance_as_of_block(Hash.Address.t(), Block.block_number() | :earliest | :latest | :pending) ::
          {:ok, Wei.t()} | {:error, :no_balance} | {:error, :not_found}
  def get_balance_as_of_block(address, block) when is_integer(block) do
    coin_balance_query =
      from(coin_balance in CoinBalance,
        where: coin_balance.address_hash == ^address,
        where: not is_nil(coin_balance.value),
        where: coin_balance.block_number <= ^block,
        order_by: [desc: coin_balance.block_number],
        limit: 1,
        select: coin_balance.value
      )

    case Repo.replica().one(coin_balance_query) do
      nil -> {:error, :not_found}
      coin_balance -> {:ok, coin_balance}
    end
  end

  def get_balance_as_of_block(address, :latest) do
    case Chain.max_consensus_block_number() do
      {:ok, latest_block_number} ->
        get_balance_as_of_block(address, latest_block_number)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def get_balance_as_of_block(address, :earliest) do
    query =
      from(coin_balance in CoinBalance,
        where: coin_balance.address_hash == ^address,
        where: not is_nil(coin_balance.value),
        where: coin_balance.block_number == 0,
        limit: 1,
        select: coin_balance.value
      )

    case Repo.replica().one(query) do
      nil -> {:error, :not_found}
      coin_balance -> {:ok, coin_balance}
    end
  end

  def get_balance_as_of_block(address, :pending) do
    query =
      case Chain.max_consensus_block_number() do
        {:ok, latest_block_number} ->
          from(coin_balance in CoinBalance,
            where: coin_balance.address_hash == ^address,
            where: not is_nil(coin_balance.value),
            where: coin_balance.block_number > ^latest_block_number,
            order_by: [desc: coin_balance.block_number],
            limit: 1,
            select: coin_balance.value
          )

        {:error, :not_found} ->
          from(coin_balance in CoinBalance,
            where: coin_balance.address_hash == ^address,
            where: not is_nil(coin_balance.value),
            order_by: [desc: coin_balance.block_number],
            limit: 1,
            select: coin_balance.value
          )
      end

    case Repo.replica().one(query) do
      nil -> {:error, :not_found}
      coin_balance -> {:ok, coin_balance}
    end
  end
end
