# credo:disable-for-this-file
defmodule Indexer.Fetcher.OnDemand.InternalTransaction do
  @moduledoc """
  Fetches internal transactions from node.
  """

  require Logger

  import Ecto.Query

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Hash, InternalTransaction, Transaction}
  alias Explorer.Repo
  alias Explorer.Utility.{AddressIdToAddressHash, InternalTransactionsAddressPlaceholder}
  alias Indexer.Fetcher.InternalTransaction, as: InternalTransactionFetcher

  @default_paging_options %PagingOptions{page_size: 50}

  @doc """
    Fetches internal transactions for the given transaction from node.

    This function acts like `Explorer.Chain.InternalTransaction.transaction_to_internal_transactions/2`
    which means that it applies paging and associations preloading and returning list of DB model records.

    ## Parameters
    - `transaction`: The transaction struct to fetch internal transactions for
    - `options`: Keyword list with optional keys:
      - `:necessity_by_association` - associations to preload as required or optional
      - `:paging_options` - pagination options including page_size and key

    ## Returns
    - List of InternalTransaction structs for the given transaction
  """
  @spec fetch_by_transaction(Transaction.t(), Keyword.t()) :: [InternalTransaction.t()]
  def fetch_by_transaction(transaction, options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    params = [
      %{
        block_number: transaction.block_number,
        hash_data: to_string(transaction.hash),
        transaction_index: transaction.index
      }
    ]

    case EthereumJSONRPC.fetch_internal_transactions(params, json_rpc_named_arguments) do
      {:ok, internal_transactions_params} ->
        internal_transactions_params
        |> Enum.map(&serialize/1)
        |> join_associations(necessity_by_association)
        |> Enum.sort_by(& &1.index)
        |> page_internal_transaction(paging_options)
        |> Enum.take(paging_options.page_size)
        |> Repo.preload(:block)

      :ignore ->
        [transaction.block_number]
        |> fetch_block_internal_transactions()
        |> Enum.map(&serialize/1)
        |> Enum.filter(&(&1.transaction_hash == transaction.hash))
        |> join_associations(necessity_by_association)
        |> Enum.sort_by(& &1.index)
        |> page_internal_transaction(paging_options)
        |> Enum.take(paging_options.page_size)
        |> Repo.preload(:block)

      error ->
        Logger.error(
          "Failed to fetch internal transactions for transaction #{inspect(transaction.hash)}: #{inspect(error)}"
        )

        []
    end
  end

  @doc """
    Fetches internal transactions for the given block from node.

    This function acts like `Explorer.Chain.InternalTransaction.block_to_internal_transactions/2`
    which means that it applies paging and associations preloading and returning list of DB model records.

    ## Parameters
    - `block_number`: The block number to fetch internal transactions for
    - `options`: Keyword list with optional keys:
      - `:necessity_by_association` - associations to preload as required or optional
      - `:paging_options` - pagination options including page_size and key
      - `:type` - filter by transaction type
      - `:call_type` - filter by call type

    ## Returns
    - List of InternalTransaction structs for the given block
  """
  @spec fetch_by_block(non_neg_integer(), Keyword.t()) :: [InternalTransaction.t()]
  def fetch_by_block(block_number, options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    type_filter = Keyword.get(options, :type)
    call_type_filter = Keyword.get(options, :call_type)

    [block_number]
    |> fetch_block_internal_transactions()
    |> Enum.map(&serialize/1)
    |> join_associations(necessity_by_association)
    |> Enum.sort_by(& &1.block_index)
    |> page_block_internal_transaction(paging_options)
    |> filter_by_type(type_filter, call_type_filter)
    |> filter_by_call_type(call_type_filter)
    |> Enum.take(paging_options.page_size)
  end

  @doc """
    Fetches internal transactions for the given address from node.

    This function acts like `Explorer.Chain.InternalTransaction.address_to_internal_transactions/2`
    which means that it applies paging and associations preloading and returning list of DB model records.

    ## Parameters
    - `address_hash`: The address hash to fetch internal transactions for
    - `options`: Keyword list with optional keys:
      - `:necessity_by_association` - associations to preload as required or optional
      - `:paging_options` - pagination options including page_size and key
      - `:direction` - if specified, will filter internal transactions by address type. If `:to` is specified, only
        internal transactions where the "to" address matches will be returned. Likewise, if `:from` is specified, only
        internal transactions where the "from" address matches will be returned. If `:direction` is omitted, internal
        transactions either to or from the address will be returned.
      - `:from_block` - lower boundary for block number
      - `:to_block` - upper boundary for block number

    ## Returns
    - List of InternalTransaction structs for the given block
  """
  @spec fetch_by_address(Hash.Address.t(), Keyword.t()) :: [InternalTransaction.t()]
  def fetch_by_address(address_hash, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    direction = Keyword.get(options, :direction)

    from_block = Chain.from_block(options)
    to_block = Chain.to_block(options)

    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    address_id = AddressIdToAddressHash.hash_to_id(address_hash)

    block_number_from_paging_options =
      case paging_options do
        %{key: {block_number, _, _}} -> block_number
        _ -> nil
      end

    max_block_number =
      case {to_block, block_number_from_paging_options} do
        {nil, nil} -> nil
        {first, second} -> max(first || 0, second || 0)
      end

    sum_mode =
      case direction do
        d when d in [:to, :to_address_hash] -> "tos"
        d when d in [:from, :from_address_hash] -> "froms"
        _ -> "both"
      end

    address_id
    |> get_block_numbers_for_address(max_block_number, from_block, paging_options.page_size, sum_mode)
    |> fetch_block_internal_transactions()
    |> Enum.map(&serialize/1)
    |> filter_by_address(address_hash, direction)
    |> join_associations(necessity_by_association)
    |> Enum.sort_by(&{&1.block_number, &1.transaction_index, &1.index}, &>=/2)
    |> page_internal_transaction(paging_options, %{index_internal_transaction_desc_order: true})
    |> Enum.take(paging_options.page_size)
  end

  defp get_block_numbers_for_address(nil, _start_block, _end_block, _limit, _sum_mode), do: []

  defp get_block_numbers_for_address(address_id, start_block, end_block, limit, sum_mode) do
    ranked_query =
      InternalTransactionsAddressPlaceholder
      |> where([q], q.address_id == ^address_id)
      |> then(fn query ->
        if is_nil(start_block) do
          query
        else
          where(query, [q], q.block_number <= ^start_block)
        end
      end)
      |> then(fn query ->
        if is_nil(end_block) do
          query
        else
          where(query, [q], q.block_number >= ^end_block)
        end
      end)
      |> windows([q], w: [order_by: [desc: :block_number]])
      |> select([q], %{
        block_number: q.block_number,
        running_sum:
          fragment(
            """
            sum(
              CASE ?
                WHEN 'froms' THEN ?
                WHEN 'tos'   THEN ?
                ELSE ? + ?
              END
            ) OVER w
            """,
            ^sum_mode,
            q.count_froms,
            q.count_tos,
            q.count_froms,
            q.count_tos
          )
      })

    cut_query =
      from(r in subquery(ranked_query),
        select: %{
          block_number: r.block_number,
          running_sum: r.running_sum,
          cutoff_block:
            fragment(
              "max(CASE WHEN ? >= ? THEN ? END) OVER ()",
              r.running_sum,
              ^limit,
              r.block_number
            )
        }
      )

    final_query =
      from(c in subquery(cut_query),
        where: is_nil(c.cutoff_block) or c.block_number >= c.cutoff_block,
        order_by: [desc: c.block_number],
        select: c.block_number
      )

    Repo.all(final_query)
  end

  defp filter_by_address(internal_transactions, address_hash, direction) do
    Enum.filter(internal_transactions, fn internal_transaction ->
      case direction do
        d when d in [:to, :to_address_hash] ->
          internal_transaction.to_address_hash == address_hash

        d when d in [:from, :from_address_hash] ->
          internal_transaction.from_address_hash == address_hash

        _ ->
          internal_transaction.to_address_hash == address_hash or
            internal_transaction.from_address_hash == address_hash or
            internal_transaction.created_contract_address_hash == address_hash
      end
    end)
  end

  defp fetch_block_internal_transactions([]), do: []

  defp fetch_block_internal_transactions(block_numbers) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

    if variant in InternalTransactionFetcher.block_traceable_variants() do
      case EthereumJSONRPC.fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments) do
        {:ok, result} ->
          result

        error ->
          Logger.error("Failed to fetch internal transactions for blocks #{block_numbers}: #{inspect(error)}")
          []
      end
    else
      Enum.reduce(block_numbers, [], fn block_number, acc_list ->
        block_number
        |> Chain.get_transactions_of_block_number()
        |> InternalTransactionFetcher.filter_non_traceable_transactions()
        |> Enum.map(
          &%{
            block_number: &1.block_number,
            hash_data: to_string(&1.hash),
            transaction_index: &1.index
          }
        )
        |> case do
          [] ->
            {:ok, []}

          transactions ->
            try do
              EthereumJSONRPC.fetch_internal_transactions(transactions, json_rpc_named_arguments)
            catch
              :exit, error ->
                {:error, error, __STACKTRACE__}
            end
        end
        |> case do
          {:ok, internal_transactions} ->
            internal_transactions ++ acc_list

          error_or_ignore ->
            Logger.error("Failed to fetch internal transactions for block #{block_number}: #{inspect(error_or_ignore)}")

            acc_list
        end
      end)
    end
  end

  defp page_internal_transaction(_, _, _ \\ %{index_internal_transaction_desc_order: false})

  defp page_internal_transaction(internal_transactions, %PagingOptions{key: nil}, _), do: internal_transactions

  defp page_internal_transaction(
         internal_transactions,
         %PagingOptions{key: {block_number, transaction_index, index}},
         %{
           index_internal_transaction_desc_order: false
         }
       ) do
    Stream.filter(
      internal_transactions,
      &(&1.block_number < block_number or (&1.block_number == block_number and &1.transaction_index < transaction_index) or
          (&1.block_number == block_number and &1.transaction_index == transaction_index and &1.index > index))
    )
  end

  defp page_internal_transaction(
         internal_transactions,
         %PagingOptions{key: {block_number, transaction_index, index}},
         %{
           index_internal_transaction_desc_order: true
         }
       ) do
    Stream.filter(
      internal_transactions,
      &(&1.block_number < block_number or (&1.block_number == block_number and &1.transaction_index < transaction_index) or
          (&1.block_number == block_number and &1.transaction_index == transaction_index and &1.index < index))
    )
  end

  defp page_internal_transaction(internal_transactions, %PagingOptions{key: {0}}, %{
         index_internal_transaction_desc_order: desc_order
       }) do
    if desc_order do
      internal_transactions
    else
      Stream.filter(internal_transactions, &(&1.index > 0))
    end
  end

  defp page_internal_transaction(internal_transactions, %PagingOptions{key: {index}}, %{
         index_internal_transaction_desc_order: desc_order
       }) do
    if desc_order do
      Stream.filter(internal_transactions, &(&1.index < index))
    else
      Stream.filter(internal_transactions, &(&1.index > index))
    end
  end

  defp page_block_internal_transaction(internal_transactions, %PagingOptions{key: %{block_index: block_index}}) do
    Stream.filter(internal_transactions, &(&1.block_index > block_index))
  end

  defp page_block_internal_transaction(internal_transactions, _), do: internal_transactions

  # filter by `type` is automatically ignored if `call_type_filter` is not empty,
  # as applying both filter simultaneously have no sense
  defp filter_by_type(internal_transactions, _, [_ | _]), do: internal_transactions
  defp filter_by_type(internal_transactions, nil, _), do: internal_transactions
  defp filter_by_type(internal_transactions, [], _), do: internal_transactions

  defp filter_by_type(internal_transactions, types, _) do
    Stream.filter(internal_transactions, &(&1.type in types))
  end

  defp filter_by_call_type(internal_transactions, []), do: internal_transactions
  defp filter_by_call_type(internal_transactions, nil), do: internal_transactions

  defp filter_by_call_type(internal_transactions, call_types) do
    Stream.filter(internal_transactions, &(&1.call_type in call_types))
  end

  defp join_associations(records, necessity_by_association)
       when is_list(records) and is_map(necessity_by_association) do
    Enum.reduce(necessity_by_association, records, fn {association, necessity}, acc ->
      join_association(acc, association, necessity)
    end)
  end

  defp join_association(records, [{association, nested_preload}], :optional)
       when is_atom(association) do
    Repo.preload(records, [{association, nested_preload}])
  end

  defp join_association(records, [{association, nested_preload}], :required)
       when is_atom(association) do
    records
    |> Repo.preload([{association, nested_preload}])
    |> Enum.filter(fn struct ->
      case Map.fetch(struct, association) do
        {:ok, value} -> not is_nil(value)
        :error -> true
      end
    end)
  end

  defp join_association(records, association, :optional) do
    Repo.preload(records, association)
  end

  defp join_association(records, association, :required) do
    records
    |> Repo.preload(association)
    |> Enum.filter(fn struct ->
      case Map.fetch(struct, association) do
        {:ok, value} ->
          case value do
            [] -> false
            nil -> false
            _ -> true
          end

        :error ->
          true
      end
    end)
  end

  defp serialize(internal_transaction_params) do
    %InternalTransaction{}
    |> InternalTransaction.changeset(internal_transaction_params)
    |> Ecto.Changeset.apply_changes()
  end
end
