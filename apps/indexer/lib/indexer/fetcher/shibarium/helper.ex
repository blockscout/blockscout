defmodule Indexer.Fetcher.Shibarium.Helper do
  @moduledoc """
  Common functions for Indexer.Fetcher.Shibarium.* modules.
  """

  import Ecto.Query

  alias Explorer.Chain.Shibarium.Bridge
  alias Explorer.Repo

  @empty_hash "0x0000000000000000000000000000000000000000000000000000000000000000"

  def calc_operation_hash(user, amount_or_id, erc1155_ids, erc1155_amounts, operation_id) do
    user_binary =
      user
      |> String.trim_leading("0x")
      |> Base.decode16!(case: :mixed)

    amount_or_id =
      if is_nil(amount_or_id) and not Enum.empty?(erc1155_ids) do
        0
      else
        amount_or_id
      end

    operation_encoded =
      ABI.encode("(address,uint256,uint256[],uint256[],uint256)", [
        {
          user_binary,
          amount_or_id,
          erc1155_ids,
          erc1155_amounts,
          operation_id
        }
      ])

    "0x" <>
      (operation_encoded
       |> ExKeccak.hash_256()
       |> Base.encode16(case: :lower))
  end

  def prepare_insert_items(operations, calling_module) do
    operations
    |> Enum.reduce([], fn op, acc ->
      if bind_existing_operation_in_db(op, calling_module) == 0 do
        [op | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn item, acc ->
      Map.put(acc, {item.operation_hash, item.l1_transaction_hash, item.l2_transaction_hash}, item)
    end)
    |> Map.values()
  end

  # credo:disable-for-next-line /Complexity/
  defp bind_existing_operation_in_db(op, calling_module) do
    {query, set} =
      case calling_module do
        Indexer.Fetcher.Shibarium.L1 ->
          {
            from(sb in Bridge,
              where:
                sb.operation_hash == ^op.operation_hash and sb.operation_type == ^op.operation_type and
                  sb.l2_transaction_hash != ^@empty_hash and sb.l1_transaction_hash == ^@empty_hash,
              order_by: [asc: sb.l2_block_number],
              limit: 1
            ),
            [l1_transaction_hash: op.l1_transaction_hash, l1_block_number: op.l1_block_number] ++
              if(op.operation_type == "deposit", do: [timestamp: op.timestamp], else: [])
          }

        Indexer.Fetcher.Shibarium.L2 ->
          {
            from(sb in Bridge,
              where:
                sb.operation_hash == ^op.operation_hash and sb.operation_type == ^op.operation_type and
                  sb.l1_transaction_hash != ^@empty_hash and sb.l2_transaction_hash == ^@empty_hash,
              order_by: [asc: sb.l1_block_number],
              limit: 1
            ),
            [l2_transaction_hash: op.l2_transaction_hash, l2_block_number: op.l2_block_number] ++
              if(op.operation_type == "withdrawal", do: [timestamp: op.timestamp], else: [])
          }

        _ ->
          raise "unsupported module"
      end

    {updated_count, _} =
      Repo.update_all(
        from(b in Bridge,
          join: s in subquery(query),
          on:
            b.operation_hash == s.operation_hash and b.l1_transaction_hash == s.l1_transaction_hash and
              b.l2_transaction_hash == s.l2_transaction_hash
        ),
        set: set
      )

    updated_count
  end
end
