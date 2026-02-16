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
  Get an order by its outputs_witness_hash.
  """
  @spec get_order_by_witness_hash(binary()) :: Order.t() | nil
  def get_order_by_witness_hash(witness_hash) do
    Repo.one(
      from(o in Order,
        where: o.outputs_witness_hash == ^witness_hash
      )
    )
  end

  @doc """
  Get all fills for a specific order by witness hash.
  """
  @spec get_fills_for_order(binary()) :: [Fill.t()]
  def get_fills_for_order(witness_hash) do
    Repo.all(
      from(f in Fill,
        where: f.outputs_witness_hash == ^witness_hash,
        order_by: [asc: f.chain_type, asc: f.block_number]
      )
    )
  end

  @doc """
  Check if an order has been filled on a specific chain.
  """
  @spec order_filled_on_chain?(binary(), :rollup | :host) :: boolean()
  def order_filled_on_chain?(witness_hash, chain_type) do
    Repo.exists?(
      from(f in Fill,
        where: f.outputs_witness_hash == ^witness_hash and f.chain_type == ^chain_type
      )
    )
  end

  @doc """
  Get unfilled orders (orders without any corresponding fills).
  """
  @spec get_unfilled_orders(non_neg_integer()) :: [Order.t()]
  def get_unfilled_orders(limit \\ 100) do
    Repo.all(
      from(o in Order,
        left_join: f in Fill,
        on: o.outputs_witness_hash == f.outputs_witness_hash,
        where: is_nil(f.outputs_witness_hash),
        limit: ^limit,
        order_by: [desc: o.block_number]
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
    orders_count = Repo.one(from(o in Order, select: count(o.outputs_witness_hash)))

    rollup_fills_count =
      Repo.one(from(f in Fill, where: f.chain_type == :rollup, select: count(f.outputs_witness_hash)))

    host_fills_count =
      Repo.one(from(f in Fill, where: f.chain_type == :host, select: count(f.outputs_witness_hash)))

    %{
      orders: orders_count || 0,
      rollup_fills: rollup_fills_count || 0,
      host_fills: host_fills_count || 0
    }
  end
end
