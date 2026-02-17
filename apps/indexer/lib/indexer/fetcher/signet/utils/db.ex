defmodule Indexer.Fetcher.Signet.Utils.Db do
  @moduledoc """
  Database utility functions for Signet order indexing.
  """

  import Ecto.Query

  alias Explorer.Chain.Signet.{Order, Fill}
  alias Explorer.Repo

  @doc """
  Get the highest indexed block number for orders.
  Returns the default if no orders exist.
  """
  @spec highest_indexed_order_block(non_neg_integer()) :: non_neg_integer()
  def highest_indexed_order_block(default \\ 0) do
    case Repo.one(from(o in Order, select: max(o.block_number))) do
      nil -> default
      block -> block
    end
  end

  @doc """
  Get the highest indexed block number for fills on a specific chain.
  Returns the default if no fills exist.
  """
  @spec highest_indexed_fill_block(:rollup | :host, non_neg_integer()) :: non_neg_integer()
  def highest_indexed_fill_block(chain_type, default \\ 0) do
    case Repo.one(
           from(f in Fill,
             where: f.chain_type == ^chain_type,
             select: max(f.block_number)
           )
         ) do
      nil -> default
      block -> block
    end
  end

  @doc """
  Get an order by its transaction hash and log index.
  """
  @spec get_order_by_tx_and_log(binary(), non_neg_integer()) :: Order.t() | nil
  def get_order_by_tx_and_log(transaction_hash, log_index) do
    Repo.one(
      from(o in Order,
        where: o.transaction_hash == ^transaction_hash and o.log_index == ^log_index
      )
    )
  end

  @doc """
  Get all orders for a specific transaction.
  """
  @spec get_orders_for_transaction(binary()) :: [Order.t()]
  def get_orders_for_transaction(transaction_hash) do
    Repo.all(
      from(o in Order,
        where: o.transaction_hash == ^transaction_hash,
        order_by: [asc: o.log_index]
      )
    )
  end

  @doc """
  Get a fill by its composite primary key.
  """
  @spec get_fill(atom(), binary(), non_neg_integer()) :: Fill.t() | nil
  def get_fill(chain_type, transaction_hash, log_index) do
    Repo.one(
      from(f in Fill,
        where: f.chain_type == ^chain_type and
               f.transaction_hash == ^transaction_hash and
               f.log_index == ^log_index
      )
    )
  end

  @doc """
  Get all fills for a specific transaction.
  """
  @spec get_fills_for_transaction(binary()) :: [Fill.t()]
  def get_fills_for_transaction(transaction_hash) do
    Repo.all(
      from(f in Fill,
        where: f.transaction_hash == ^transaction_hash,
        order_by: [asc: f.chain_type, asc: f.log_index]
      )
    )
  end

  @doc """
  Get orders by deadline range for monitoring.
  """
  @spec get_orders_by_deadline_range(non_neg_integer(), non_neg_integer()) :: [Order.t()]
  def get_orders_by_deadline_range(from_deadline, to_deadline) do
    Repo.all(
      from(o in Order,
        where: o.deadline >= ^from_deadline and o.deadline <= ^to_deadline,
        order_by: [asc: o.deadline]
      )
    )
  end

  @doc """
  Count orders and fills for metrics.
  """
  @spec get_order_fill_counts() :: %{orders: non_neg_integer(), rollup_fills: non_neg_integer(), host_fills: non_neg_integer()}
  def get_order_fill_counts do
    orders_count = Repo.one(from(o in Order, select: count(o.transaction_hash)))

    rollup_fills_count =
      Repo.one(from(f in Fill, where: f.chain_type == :rollup, select: count(f.transaction_hash)))

    host_fills_count =
      Repo.one(from(f in Fill, where: f.chain_type == :host, select: count(f.transaction_hash)))

    %{
      orders: orders_count || 0,
      rollup_fills: rollup_fills_count || 0,
      host_fills: host_fills_count || 0
    }
  end
end
