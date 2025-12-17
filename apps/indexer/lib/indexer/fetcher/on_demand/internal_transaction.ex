# credo:disable-for-this-file
defmodule Indexer.Fetcher.OnDemand.InternalTransaction do
  @moduledoc """
  Fetches internal transactions from node.
  """

  require Logger

  import Ecto.Query

  alias Explorer.{Chain, Etherscan, PagingOptions}
  alias Explorer.Chain.{Block, BlockNumberHelper, Hash, InternalTransaction, Transaction}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Repo
  alias Explorer.Utility.{AddressIdToAddressHash, InternalTransactionsAddressPlaceholder}
  alias Indexer.Fetcher.InternalTransaction, as: InternalTransactionFetcher

  @default_paging_options %PagingOptions{page_size: 50}

  @doc """
    Determines whether internal transactions should be fetched on-demand based on DB records and limit.

    ## Parameters
    - `records_from_db`: List of internal transaction records from the database
    - `limit`: The number of records requested

    ## Returns
    - `true` if on-demand fetching is needed
    - `false` if DB records are sufficient
  """
  @spec should_fetch?([InternalTransaction.t()], non_neg_integer()) :: boolean()
  def should_fetch?(_records, 0), do: false

  def should_fetch?(records_from_db, limit) do
    with true <- Enum.count(records_from_db) >= limit,
         %{block_number: min_block_number} <- Enum.min_by(records_from_db, & &1.block_number),
         true <- InternalTransaction.present_in_db?(min_block_number) do
      false
    else
      _ -> true
    end
  end

  @doc """
    Fetches latest internal transactions.

    This function acts like `Explorer.Chain.InternalTransaction.fetch/2` without `transaction_hash`
    which means that it applies paging and associations preloading and returning list of DB model records.

    ## Parameters
    - `options`: Keyword list with optional keys:
      - `:necessity_by_association` - associations to preload as required or optional
      - `:paging_options` - pagination options including page_size and key

    ## Returns
    - List of latest InternalTransaction structs
  """
  @spec fetch_latest(Keyword.t()) :: [InternalTransaction.t()]
  def fetch_latest(options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    from_block = Chain.from_block(options)
    to_block = Chain.to_block(options)

    to_block_number =
      case {paging_options, to_block} do
        {%PagingOptions{key: {block_number, _, _}}, _} -> block_number
        {_, block_number} when is_integer(block_number) -> block_number
        _ -> BlockNumber.get_max()
      end

    sort_direction =
      case Keyword.get(options, :sort_direction) do
        :asc -> &<=/2
        _ -> &>=/2
      end

    index_internal_transaction_desc_order = Keyword.get(options, :index_internal_transaction_desc_order, true)

    to_block_number
    |> fetch_enough(from_block || 0, paging_options.page_size, options)
    |> Enum.sort_by(&{&1.block_number, &1.transaction_index, &1.index}, sort_direction)
    |> page_internal_transaction(paging_options, %{
      index_internal_transaction_desc_order: index_internal_transaction_desc_order
    })
    |> Enum.take(paging_options.page_size)
  end

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
        |> different_from_parent_transaction()
        |> Enum.sort_by(& &1.index)
        |> add_block_hashes(transaction.block_hash)
        |> join_associations(necessity_by_association)
        |> page_internal_transaction(paging_options)
        |> Enum.take(paging_options.page_size)
        |> Repo.preload(:block)

      :ignore ->
        [transaction.block_number]
        |> fetch_block_internal_transactions()
        |> Enum.map(&serialize/1)
        |> Enum.filter(&(&1.transaction_hash == transaction.hash))
        |> different_from_parent_transaction()
        |> Enum.sort_by(& &1.index)
        |> add_block_hashes(transaction.block_hash)
        |> join_associations(necessity_by_association)
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
  @spec fetch_by_block(map() | non_neg_integer(), Keyword.t()) :: [InternalTransaction.t()]
  def fetch_by_block(block, options \\ [])

  def fetch_by_block(block_number, options) when is_integer(block_number) do
    fetch_by_block(%Block{number: block_number, hash: nil}, options)
  end

  def fetch_by_block(%Block{} = block, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    type_filter = Keyword.get(options, :type)
    call_type_filter = Keyword.get(options, :call_type)
    unlimited? = Keyword.get(options, :unlimited)

    [block.number]
    |> fetch_block_internal_transactions()
    |> Enum.map(&serialize/1)
    |> different_from_parent_transaction()
    |> filter_by_type(type_filter, call_type_filter)
    |> filter_by_call_type(call_type_filter)
    |> page_block_internal_transaction(paging_options)
    |> Enum.sort_by(&{&1.transaction_index, &1.index})
    |> then(&if unlimited?, do: &1, else: Enum.take(&1, paging_options.page_size))
    |> add_block_hashes(block.hash)
    |> join_associations(necessity_by_association)
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
    - List of InternalTransaction structs for the given address
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
        {nil, key} -> key
        {to, nil} -> to
        {to, key} -> min(to, key)
      end

    sum_mode =
      case direction do
        d when d in [:to, :to_address_hash] -> "tos"
        d when d in [:from, :from_address_hash] -> "froms"
        _ -> "both"
      end

    sort_direction = Keyword.get(options, :sort_direction, :desc)

    sort_func =
      case sort_direction do
        :asc -> &<=/2
        _ -> &>=/2
      end

    index_internal_transaction_desc_order = Keyword.get(options, :index_internal_transaction_desc_order, true)

    address_id
    |> do_fetch_for_address(max_block_number, from_block, paging_options.page_size, sum_mode, sort_direction)
    |> Enum.map(&serialize/1)
    |> filter_by_address(address_hash, direction)
    |> different_from_parent_transaction()
    |> page_internal_transaction(paging_options, %{
      index_internal_transaction_desc_order: index_internal_transaction_desc_order
    })
    |> Enum.sort_by(&{&1.block_number, &1.transaction_index, &1.index}, sort_func)
    |> Enum.take(paging_options.page_size)
    |> add_block_hashes()
    |> join_associations(necessity_by_association)
    |> Repo.preload(:block)
  end

  defp do_fetch_for_address(address_id, to_block, from_block, limit, sum_mode, sort_direction, acc \\ [])

  defp do_fetch_for_address(_, to_block, from_block, _, _, _, acc)
       when is_integer(from_block) and is_integer(to_block) and from_block >= to_block, do: acc

  defp do_fetch_for_address(address_id, to_block, from_block, limit, sum_mode, sort_direction, acc) do
    internal_transactions =
      address_id
      |> get_block_numbers_for_address(to_block, from_block, limit, sum_mode, sort_direction)
      |> fetch_block_internal_transactions()

    result = Enum.concat(internal_transactions, acc)

    count =
      internal_transactions
      |> different_from_parent_transaction()
      |> Enum.count()

    if count > 0 and count < limit do
      case sort_direction do
        :desc ->
          do_fetch_for_address(
            address_id,
            List.last(internal_transactions).block_number - 1,
            from_block,
            limit - count,
            sum_mode,
            sort_direction,
            result
          )

        :asc ->
          do_fetch_for_address(
            address_id,
            to_block,
            List.last(internal_transactions).block_number + 1,
            limit - count,
            sum_mode,
            sort_direction,
            result
          )
      end
    else
      result
    end
  end

  @doc """
    Fetches internal transactions for the given transaction from node, formatted for Etherscan API compatibility.

    ## Parameters
    - `transaction`: The transaction struct to fetch internal transactions for
    - `raw_options`: Map of Etherscan-compatible options including page_size

    ## Returns
    - List of internal transactions serialized in Etherscan format
  """
  @spec etherscan_fetch_by_transaction(Transaction.t(), map()) :: [map()]
  def etherscan_fetch_by_transaction(transaction, raw_options) do
    options = Map.merge(Etherscan.default_options(), raw_options)

    transaction
    |> fetch_by_transaction(paging_options: %PagingOptions{page_size: options.page_size})
    |> Enum.map(&etherscan_serialize/1)
  end

  @doc """
    Fetches internal transactions for the given address from node, formatted for Etherscan API compatibility.

    ## Parameters
    - `address_hash`: The address hash to fetch internal transactions for
    - `raw_options`: Map of Etherscan-compatible options including page_size, direction filter, and block range

    ## Returns
    - List of internal transactions serialized in Etherscan format
  """
  @spec etherscan_fetch_by_address(Hash.Address.t(), map()) :: [map()]
  def etherscan_fetch_by_address(address_hash, raw_options) do
    options = Map.merge(Etherscan.default_options(), raw_options)

    direction =
      case options do
        %{filter_by: "to"} -> :to
        %{filter_by: "from"} -> :from
        _ -> :both
      end

    prepared_options = [
      paging_options: %PagingOptions{page_size: options.page_size, page_number: options.page_number},
      direction: direction,
      from_block: Map.get(options, :startblock),
      to_block: Map.get(options, :endblock),
      sort_direction: Map.get(options, :order_by_direction),
      index_internal_transaction_desc_order: Map.get(options, :order_by_direction) != :asc
    ]

    address_hash
    |> fetch_by_address(prepared_options)
    |> Repo.preload(:block)
    |> Enum.map(&etherscan_serialize/1)
  end

  @doc """
    Fetches latest internal transactions from node, formatted for Etherscan API compatibility.

    ## Parameters
    - `raw_options`: Map of Etherscan-compatible options including page_size, page_number, and block range

    ## Returns
    - List of internal transactions serialized in Etherscan format
  """
  @spec etherscan_fetch_latest(map()) :: [map()]
  def etherscan_fetch_latest(raw_options) do
    options = Map.merge(Etherscan.default_options(), raw_options)

    prepared_options = [
      paging_options: %PagingOptions{page_size: options.page_size, page_number: options.page_number},
      from_block: Map.get(options, :startblock),
      to_block: Map.get(options, :endblock),
      sort_direction: Map.get(options, :order_by_direction),
      index_internal_transaction_desc_order: Map.get(options, :order_by_direction) != :asc
    ]

    prepared_options
    |> fetch_latest()
    |> different_from_parent_transaction()
    |> Repo.preload(:block)
    |> Enum.map(&etherscan_serialize/1)
  end

  defp fetch_enough(start_block_number, end_block_number, count, options, acc \\ [])

  defp fetch_enough(start_number, end_number, count, options, acc) when start_number >= end_number do
    internal_transactions = fetch_by_block(start_number, Keyword.put(options, :unlimited, true))
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    fetched_count =
      internal_transactions
      |> page_internal_transaction(paging_options, %{index_internal_transaction_desc_order: true})
      |> Enum.count()

    result = Enum.concat(acc, internal_transactions)

    if fetched_count >= count or start_number == 0 do
      result
    else
      start_number
      |> BlockNumberHelper.previous_block_number()
      |> fetch_enough(end_number, count - fetched_count, options, result)
    end
  end

  defp fetch_enough(_start_number, _end_number, _count, _options, acc), do: acc

  defp get_block_numbers_for_address(nil, _end_block, _start_block, _limit, _sum_mode, _order), do: []

  defp get_block_numbers_for_address(address_id, end_block, start_block, limit, sum_mode, order) do
    ranked_query =
      InternalTransactionsAddressPlaceholder
      |> where([q], q.address_id == ^address_id)
      |> then(fn query ->
        if is_nil(end_block) do
          query
        else
          where(query, [q], q.block_number <= ^end_block)
        end
      end)
      |> then(fn query ->
        if is_nil(start_block) do
          query
        else
          where(query, [q], q.block_number >= ^start_block)
        end
      end)
      |> windows([q], w: [order_by: [{^order, :block_number}]])
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

    condition =
      case order do
        :desc -> dynamic([c], is_nil(c.cutoff_block) or c.block_number >= c.cutoff_block)
        :asc -> dynamic([c], is_nil(c.cutoff_block) or c.block_number <= c.cutoff_block)
      end

    final_query =
      from(c in subquery(cut_query),
        where: ^condition,
        order_by: [{^order, c.block_number}],
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
          Logger.error("Failed to fetch internal transactions for blocks #{inspect(block_numbers)}: #{inspect(error)}")
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

  defp page_block_internal_transaction(internal_transactions, %PagingOptions{
         key: %{transaction_index: transaction_index, index: index}
       }) do
    Stream.filter(
      internal_transactions,
      &((&1.transaction_index == transaction_index and &1.index > index) or &1.transaction_index > transaction_index)
    )
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

  defp add_block_hashes(internal_transactions, block_hash \\ nil) do
    block_number_to_hash_map =
      case block_hash do
        nil ->
          internal_transactions
          |> Enum.map(& &1.transaction_hash)
          |> Enum.uniq()
          |> Transaction.by_hashes_query()
          |> select([t], {t.block_number, t.block_hash})
          |> Repo.all()
          |> Map.new()

        _ ->
          %{}
      end

    Enum.map(internal_transactions, &%{&1 | block_hash: block_hash || block_number_to_hash_map[&1.block_number]})
  end

  defp different_from_parent_transaction(internal_transactions) do
    Enum.reject(internal_transactions, &(&1.type == :call and &1.index == 0))
  end

  defp serialize(internal_transaction_params) do
    %InternalTransaction{}
    |> InternalTransaction.changeset(internal_transaction_params)
    |> Ecto.Changeset.apply_changes()
  end

  defp etherscan_serialize(internal_transaction) do
    internal_transaction
    |> Map.take(Etherscan.internal_transaction_fields())
    |> Map.put(:block_timestamp, internal_transaction.block.timestamp)
  end
end
