defmodule BlockScoutWeb.Resolvers.Transaction do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.Address

  def get_by(_, %{hash: hash}, _) do
    case Chain.hash_to_transaction(hash) do
      {:ok, transaction} -> {:ok, transaction}
      {:error, :not_found} -> {:error, "Transaction not found."}
    end
  end

  def get_by(%Address{hash: address_hash}, args, _) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    case {get_range_start(Map.get(args, :range_start)), get_range_end(Map.get(args, :range_end))} do
      {{:error, reason}, _} -> {:error, reason}
      {_, {:error, reason}} -> {:error, reason}
      {range_start, range_end} ->
        address_hash
          |> GraphQL.address_to_transactions_query(args.order, range_start, range_end)
          |> Connection.from_query(&Repo.all/1, connection_args, options(args))
    end
  end

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []

  @spec get_range_start(nil | :block_tx_pair) :: (nil | {:ok, {Explorer.Chain.Block.block_number(), non_neg_integer()}} | {:error, String.t()})
  defp get_range_start(maybe_range_start) do
    case maybe_range_start do
      nil -> nil
      value when value != nil ->
        case get_by(%{}, %{hash: value.tx_hash}, %{}) do
          {:ok, transaction} ->
            case value.block_hash == transaction.block_hash do
              true -> {:ok, {transaction.block_number, transaction.index}}
              # rollback caused tx to still be in the blockchain, but in a different block
              false -> {:error, "Referenced block did not match"}
            end
          _ -> {:error, "Referenced transaction not found"}
        end
    end
  end

  @spec get_range_end(nil | :full_hash) :: nil | {:ok, pos_integer()} | {:error, String.t()}
  defp get_range_end(maybe_range_end) do
    case maybe_range_end do
      nil -> nil
      block_hash when block_hash != nil ->
        case Chain.hash_to_block(block_hash) do
          {:ok, block} -> {:ok, block.number}
          _ -> {:error, "Range end block not found"}
        end
    end
  end
end
