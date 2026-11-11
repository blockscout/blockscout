# SPDX-License-Identifier: LicenseRef-Blockscout
# credo:disable-for-this-file
defmodule Indexer.Fetcher.OnDemand.InternalTransaction do
  @moduledoc """
  Fetches internal transactions from node.
  """

  require Logger

  import Ecto.Query

  alias Explorer.{Chain, Etherscan, PagingOptions}
  alias Explorer.Chain.{Block, BlockNumberHelper, Hash, InternalTransaction, Transaction, Wei}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Utility.{AddressIdToAddressHash, InternalTransactionsAddressPlaceholder}
  alias Indexer.Fetcher.InternalTransaction, as: InternalTransactionFetcher

  @default_paging_options %PagingOptions{page_size: 50}

  # Limit how many trace requests are sent to the node in one JSON-RPC batch.
  # Without them, all block/transaction trace calls of an on-demand fetch end up
  # in a single batch (the transport-level ETHEREUM_JSONRPC_HTTP_BATCH_SIZE
  # default of 500 is tuned for cheap calls, not traces), sharing one timeout
  # window on the archive node. Batches are sent in parallel.
  @default_blocks_batch_size 2
  @default_transactions_batch_size 20

  # Limits the rounds of tracing the blocks of an address in one request, see `do_fetch_for_address/4`
  @max_address_fetch_rounds 5

  # Limits the blocks traced one by one for the latest internal transactions in one request, see `fetch_enough/4`
  @max_latest_fetch_blocks 100

  @typedoc """
  The result of `fetch_latest/1` and `etherscan_fetch_latest/1`. With `:incomplete`, the internal transactions of
  the blocks from `next_block_number` on (in the scan direction) are not fetched.
  """
  @type latest_result(item) :: {:ok, [item]} | {:incomplete, [item], next_block_number :: non_neg_integer()}

  @doc """
    Determines whether internal transactions should be fetched on-demand based on DB records and limit.

    ## Parameters
    - `records_from_db`: List of internal transaction records from the database
    - `limit`: The number of records requested
    - `include_zero_value?`: Whether zero-value calls are requested. Only they are deleted from the DB
      by the DeleteZeroValueInternalTransactions migration, so the DB records are sufficient without them,
      unless the internal transactions storage is disabled.

    ## Returns
    - `true` if on-demand fetching is needed
    - `false` if DB records are sufficient
  """
  @spec should_fetch?([InternalTransaction.t()], non_neg_integer(), boolean()) :: boolean()
  def should_fetch?(records_from_db, limit, include_zero_value? \\ true)

  def should_fetch?(_records, 0, _include_zero_value?), do: false

  def should_fetch?(records_from_db, limit, include_zero_value?) do
    cond do
      internal_transactions_fetching_disabled?() ->
        false

      not include_zero_value? and not InternalTransaction.storage_disabled?() ->
        false

      true ->
        with true <- Enum.count(records_from_db) >= limit,
             %{block_number: min_block_number} <- Enum.min_by(records_from_db, & &1.block_number),
             true <- InternalTransaction.present_in_db?(min_block_number) do
          false
        else
          _ -> not InternalTransactionsAddressPlaceholder.empty?()
        end
    end
  end

  @doc """
    Fetches latest internal transactions.

    This function acts like `Explorer.Chain.InternalTransaction.fetch/2` without `transaction_hash`
    which means that it applies paging and associations preloading and returning list of DB model records.

    ## Parameters
    - `options`: Keyword list with optional keys:
      - `:necessity_by_association` - associations to preload as required or optional
      - `:paging_options` - pagination options including page_size and key. The key is supported in descending
        order only
      - `:sort_direction` - `:asc` for the oldest internal transactions, the latest ones otherwise
      - `:from_block` - lower boundary for block number
      - `:to_block` - upper boundary for block number

    The blocks are traced one by one, at most `#{@max_latest_fetch_blocks}` of them, until the page is filled. The
    search also stops at a block that fails to be traced, not to leave a gap. In both cases the result is
    incomplete: the internal transactions found so far and the block to go on with.

    ## Returns
    - `{:ok, internal_transactions}` with the latest InternalTransaction structs
    - `{:incomplete, internal_transactions, next_block_number}` when the blocks from `next_block_number` on (in the
      scan direction) are not traced
  """
  @spec fetch_latest(Keyword.t()) :: latest_result(InternalTransaction.t())
  def fetch_latest(options) do
    if internal_transactions_fetching_disabled?() do
      {:ok, []}
    else
      paging_options = Keyword.get(options, :paging_options, @default_paging_options)

      from_block = Chain.from_block(options)
      to_block = Chain.to_block(options)

      case Keyword.get(options, :sort_direction) do
        :asc ->
          # the oldest internal transactions are found by tracing the blocks up from the lower boundary
          (from_block || 0)
          |> fetch_enough(
            %{
              last_block_number: to_block || BlockNumber.get_max(),
              direction: :asc,
              count: paging_options.page_size,
              blocks_left: @max_latest_fetch_blocks
            },
            options
          )
          |> map_latest_result(fn internal_transactions ->
            internal_transactions
            |> Enum.sort_by(&{&1.block_number, &1.transaction_index, &1.index}, &<=/2)
            |> Enum.take(paging_options.page_size)
          end)

        _ ->
          to_block_number =
            case {paging_options, to_block} do
              {%PagingOptions{key: {block_number, _, _}}, _} -> block_number
              {_, block_number} when is_integer(block_number) -> block_number
              _ -> BlockNumber.get_max()
            end

          index_internal_transaction_desc_order = Keyword.get(options, :index_internal_transaction_desc_order, true)

          to_block_number
          |> fetch_enough(
            %{
              last_block_number: from_block || 0,
              direction: :desc,
              count: paging_options.page_size,
              blocks_left: @max_latest_fetch_blocks
            },
            options
          )
          |> map_latest_result(fn internal_transactions ->
            internal_transactions
            |> Enum.sort_by(&{&1.block_number, &1.transaction_index, &1.index}, &>=/2)
            |> page_internal_transaction(paging_options, %{
              index_internal_transaction_desc_order: index_internal_transaction_desc_order
            })
            |> Enum.take(paging_options.page_size)
          end)
      end
    end
  end

  @doc """
  Applies `fun` to the internal transactions of the result of `fetch_latest/1` or `etherscan_fetch_latest/1`,
  keeping the status.
  """
  @spec map_latest_result(latest_result(item), ([item] -> [result_item])) :: latest_result(result_item)
        when item: term(), result_item: term()
  def map_latest_result({:ok, internal_transactions}, fun), do: {:ok, fun.(internal_transactions)}

  def map_latest_result({:incomplete, internal_transactions, next_block_number}, fun),
    do: {:incomplete, fun.(internal_transactions), next_block_number}

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
    if internal_transactions_fetching_disabled?() do
      []
    else
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
          |> filter_zero_value(options)
          |> Enum.sort_by(& &1.index)
          |> join_associations(necessity_by_association, options)
          |> page_internal_transaction(paging_options)
          |> Enum.take(paging_options.page_size)
          |> Chain.select_repo(options).preload(:block)
          |> InternalTransaction.preload_error(options)
          |> InternalTransaction.preload_transaction()
          |> InternalTransaction.preload_addresses(options)

        :ignore ->
          [transaction.block_number]
          |> fetch_block_internal_transactions(options)
          |> Enum.map(&serialize/1)
          |> Enum.filter(&(&1.block_number == transaction.block_number and &1.transaction_index == transaction.index))
          |> different_from_parent_transaction()
          |> filter_zero_value(options)
          |> Enum.sort_by(& &1.index)
          |> join_associations(necessity_by_association, options)
          |> page_internal_transaction(paging_options)
          |> Enum.take(paging_options.page_size)
          |> Chain.select_repo(options).preload(:block)
          |> InternalTransaction.preload_error(options)
          |> InternalTransaction.preload_transaction()
          |> InternalTransaction.preload_addresses(options)

        error ->
          Logger.error(
            "Failed to fetch internal transactions for transaction #{inspect(transaction.hash)}: #{inspect(error)}"
          )

          []
      end
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
    if internal_transactions_fetching_disabled?() do
      []
    else
      # a partially traced block gives the internal transactions that are traced
      {_status, internal_transactions} = block_internal_transactions(block, options)
      internal_transactions
    end
  end

  # Returns `{:error, internal_transactions}` with the traced part of the internal transactions when the block fails
  # to be traced completely
  defp block_internal_transactions(block, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    type_filter = Keyword.get(options, :type)
    call_type_filter = Keyword.get(options, :call_type)
    unlimited? = Keyword.get(options, :unlimited)

    {status, internal_transactions_params} = trace_blocks([block.number], options)

    internal_transactions =
      internal_transactions_params
      |> Enum.map(&serialize/1)
      |> different_from_parent_transaction()
      |> filter_zero_value(options)
      |> filter_by_type(type_filter, call_type_filter)
      |> filter_by_call_type(call_type_filter)
      |> page_block_internal_transaction(paging_options)
      |> Enum.sort_by(&{&1.transaction_index, &1.index})
      |> then(&if unlimited?, do: &1, else: Enum.take(&1, paging_options.page_size))
      |> join_associations(necessity_by_association, options)
      |> InternalTransaction.preload_error(options)
      |> InternalTransaction.preload_transaction()

    {status, internal_transactions}
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
    if internal_transactions_fetching_disabled?() do
      []
    else
      necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
      direction = Keyword.get(options, :direction)

      from_block = Chain.from_block(options)
      to_block = Chain.to_block(options)

      paging_options = Keyword.get(options, :paging_options, @default_paging_options)

      address_id = AddressIdToAddressHash.hash_to_id(address_hash, options)

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

      sort_direction = if Keyword.get(options, :sort_direction) == :asc, do: :asc, else: :desc

      index_internal_transaction_desc_order = Keyword.get(options, :index_internal_transaction_desc_order, true)

      select_matching = fn internal_transactions_params ->
        internal_transactions_params
        |> Enum.map(&serialize/1)
        |> filter_by_address(address_hash, direction)
        |> different_from_parent_transaction()
        |> filter_zero_value(options)
        |> page_internal_transaction(paging_options, %{
          index_internal_transaction_desc_order: index_internal_transaction_desc_order
        })
        |> Enum.to_list()
      end

      sort_func = if sort_direction == :asc, do: &<=/2, else: &>=/2

      address_id
      |> do_fetch_for_address(
        %{
          to_block: max_block_number,
          from_block: from_block,
          limit: paging_options.page_size,
          sum_mode: sum_mode,
          sort_direction: sort_direction,
          select_matching: select_matching,
          rounds_left: @max_address_fetch_rounds
        },
        options
      )
      |> Enum.sort_by(&{&1.block_number, &1.transaction_index, &1.index}, sort_func)
      |> Enum.take(paging_options.page_size)
      |> join_associations(necessity_by_association, options)
      |> Chain.select_repo(options).preload(:block)
      |> InternalTransaction.preload_error(options)
      |> InternalTransaction.preload_transaction()
    end
  end

  # The placeholder counts only tell how many blocks to trace. A traced block can give fewer matching internal
  # transactions: the paging key cuts off its beginning, zero-value calls get filtered out, a self-call is counted
  # in both directions, and the placeholders of a reorged block can be outdated. So the blocks are traced in rounds,
  # each one going on past the last traced block with the internal transactions still missing, until they are found,
  # the placeholders are over, the node fails, or `@max_address_fetch_rounds` is reached.
  defp do_fetch_for_address(address_id, params, options, acc \\ [])

  defp do_fetch_for_address(_address_id, %{limit: limit}, _options, acc) when limit <= 0, do: acc

  defp do_fetch_for_address(_address_id, %{rounds_left: 0}, _options, acc), do: acc

  defp do_fetch_for_address(_address_id, %{from_block: from_block, to_block: to_block}, _options, acc)
       when is_integer(from_block) and is_integer(to_block) and from_block > to_block,
       do: acc

  defp do_fetch_for_address(address_id, params, options, acc) do
    block_numbers = get_block_numbers_for_address(address_id, params, options)

    with [_ | _] <- block_numbers,
         {:ok, internal_transactions_params} <- trace_blocks(block_numbers, options) do
      matching_internal_transactions = params.select_matching.(internal_transactions_params)
      last_block_number = List.last(block_numbers)

      next_params =
        case params.sort_direction do
          :asc -> %{params | from_block: last_block_number + 1}
          :desc -> %{params | to_block: last_block_number - 1}
        end

      do_fetch_for_address(
        address_id,
        %{
          next_params
          | limit: params.limit - Enum.count(matching_internal_transactions),
            rounds_left: params.rounds_left - 1
        },
        options,
        acc ++ matching_internal_transactions
      )
    else
      _ -> acc
    end
  end

  @doc """
    Fetches internal transactions for the given transaction from node, formatted for Etherscan API compatibility.

    Like `Explorer.Etherscan.list_internal_transactions/2`, it returns up to `Explorer.Etherscan.page_size_max/0`
    internal transactions of the transaction, ordered by `order_by_direction`.

    ## Parameters
    - `transaction`: The transaction struct to fetch internal transactions for
    - `raw_options`: Map of Etherscan-compatible options including include_zero_value and order_by_direction

    ## Returns
    - List of internal transactions serialized in Etherscan format
  """
  @spec etherscan_fetch_by_transaction(Transaction.t(), map()) :: [map()]
  def etherscan_fetch_by_transaction(transaction, raw_options) do
    options = Map.merge(Etherscan.default_options(), raw_options)

    transaction
    |> fetch_by_transaction(
      paging_options: %PagingOptions{page_size: Etherscan.page_size_max()},
      include_zero_value: options.include_zero_value,
      api?: true
    )
    |> Enum.sort_by(& &1.index, options.order_by_direction)
    |> Enum.map(&etherscan_serialize/1)
  end

  @doc """
    Fetches internal transactions for the given address from node, formatted for Etherscan API compatibility.

    ## Parameters
    - `address_hash`: The address hash to fetch internal transactions for
    - `raw_options`: Map of Etherscan-compatible options including page_size, page_number, direction filter,
      include_zero_value and block range

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
      paging_options: etherscan_paging_options(options),
      direction: direction,
      from_block: Map.get(options, :startblock),
      to_block: Map.get(options, :endblock),
      sort_direction: Map.get(options, :order_by_direction),
      index_internal_transaction_desc_order: Map.get(options, :order_by_direction) != :asc,
      include_zero_value: options.include_zero_value,
      api?: true
    ]

    address_hash
    |> fetch_by_address(prepared_options)
    |> etherscan_page(options)
    |> Chain.select_repo(prepared_options).preload(:block)
    |> Enum.map(&etherscan_serialize/1)
  end

  @doc """
    Fetches latest internal transactions from node, formatted for Etherscan API compatibility.

    ## Parameters
    - `raw_options`: Map of Etherscan-compatible options including page_size, page_number, include_zero_value
      and block range

    ## Returns
    - `{:ok, internal_transactions}` with the requested page of internal transactions serialized in Etherscan format
    - `{:incomplete, internal_transactions, next_block_number}` when the blocks from `next_block_number` on are not
      traced, see `fetch_latest/1`
  """
  @spec etherscan_fetch_latest(map()) :: latest_result(map())
  def etherscan_fetch_latest(raw_options) do
    options = Map.merge(Etherscan.default_options(), raw_options)

    prepared_options = [
      paging_options: etherscan_paging_options(options),
      from_block: Map.get(options, :startblock),
      to_block: Map.get(options, :endblock),
      sort_direction: Map.get(options, :order_by_direction),
      index_internal_transaction_desc_order: Map.get(options, :order_by_direction) != :asc,
      include_zero_value: options.include_zero_value,
      api?: true
    ]

    prepared_options
    |> fetch_latest()
    |> map_latest_result(fn internal_transactions ->
      internal_transactions
      |> different_from_parent_transaction()
      |> etherscan_page(options)
      |> Chain.select_repo(prepared_options).preload(:block)
      |> Enum.map(&etherscan_serialize/1)
    end)
  end

  # Traces the blocks one by one, from `block_number` towards `last_block_number`, until `count` internal
  # transactions are found. On a chain with few internal transactions (empty blocks, `include_zero_value: false`)
  # one request could trace thousands of blocks this way, so it stops after `blocks_left` blocks. It also stops at a
  # block that fails to be traced, not to leave a gap in the results. In both cases, the result is incomplete with
  # the block to go on with.
  defp fetch_enough(block_number, params, options, acc \\ [])

  defp fetch_enough(block_number, %{direction: :desc, last_block_number: last_block_number}, _options, acc)
       when block_number < last_block_number,
       do: {:ok, acc}

  defp fetch_enough(block_number, %{direction: :asc, last_block_number: last_block_number}, _options, acc)
       when block_number > last_block_number,
       do: {:ok, acc}

  defp fetch_enough(block_number, %{blocks_left: 0}, _options, acc), do: {:incomplete, acc, block_number}

  defp fetch_enough(block_number, %{direction: direction, count: count} = params, options, acc) do
    case block_internal_transactions(%Block{number: block_number, hash: nil}, Keyword.put(options, :unlimited, true)) do
      {:ok, internal_transactions} ->
        fetched_count =
          case direction do
            :desc ->
              paging_options = Keyword.get(options, :paging_options, @default_paging_options)

              internal_transactions
              |> page_internal_transaction(paging_options, %{index_internal_transaction_desc_order: true})
              |> Enum.count()

            :asc ->
              Enum.count(internal_transactions)
          end

        result = Enum.concat(acc, internal_transactions)

        if fetched_count >= count or (direction == :desc and block_number == 0) do
          {:ok, result}
        else
          block_number
          |> neighbor_block_number(direction)
          |> fetch_enough(
            %{params | count: count - fetched_count, blocks_left: params.blocks_left - 1},
            options,
            result
          )
        end

      {:error, _traced_internal_transactions} ->
        {:incomplete, acc, block_number}
    end
  end

  defp neighbor_block_number(block_number, :desc), do: BlockNumberHelper.previous_block_number(block_number)
  defp neighbor_block_number(block_number, :asc), do: BlockNumberHelper.next_block_number(block_number)

  # Returns the blocks to trace next for the address: its blocks within the boundaries, in `sort_direction` order,
  # until their placeholders count `limit` internal transactions
  defp get_block_numbers_for_address(nil, _params, _options), do: []

  defp get_block_numbers_for_address(
         address_id,
         %{to_block: to_block, from_block: from_block, limit: limit, sum_mode: sum_mode, sort_direction: order},
         options
       ) do
    counts_query =
      InternalTransactionsAddressPlaceholder
      |> where([placeholder], placeholder.address_id == ^address_id)
      |> then(&if(is_nil(to_block), do: &1, else: where(&1, [placeholder], placeholder.block_number <= ^to_block)))
      |> then(&if(is_nil(from_block), do: &1, else: where(&1, [placeholder], placeholder.block_number >= ^from_block)))
      |> select([placeholder], %{
        block_number: placeholder.block_number,
        count:
          fragment(
            "CASE ? WHEN 'froms' THEN ?::integer WHEN 'tos' THEN ?::integer ELSE ?::integer + ? END",
            ^sum_mode,
            placeholder.count_froms,
            placeholder.count_tos,
            placeholder.count_froms,
            placeholder.count_tos
          )
      })

    # Each of these placeholders counts at least one internal transaction, so the first `limit` of them are enough
    # to count `limit` internal transactions, and the rest of the address placeholders are not read
    candidates_query =
      from(
        placeholder in subquery(counts_query),
        where: placeholder.count > 0,
        order_by: [{^order, placeholder.block_number}],
        limit: ^limit
      )

    from(
      placeholder in subquery(candidates_query),
      windows: [w: [order_by: [{^order, placeholder.block_number}]]],
      select: %{
        block_number: placeholder.block_number,
        preceding_count: fragment("sum(?) OVER w - ?", placeholder.count, placeholder.count)
      }
    )
    |> subquery()
    |> where([placeholder], placeholder.preceding_count < ^limit)
    |> order_by([placeholder], [{^order, placeholder.block_number}])
    |> select([placeholder], placeholder.block_number)
    |> Chain.select_repo(options).all()
  end

  defp filter_by_address(internal_transactions, address_hash, direction) do
    Enum.filter(internal_transactions, fn internal_transaction ->
      case direction do
        :to ->
          internal_transaction.to_address_hash == address_hash

        :to_address_hash ->
          internal_transaction.to_address_hash == address_hash and
            is_nil(internal_transaction.created_contract_address_hash)

        d when d in [:from, :from_address_hash] ->
          internal_transaction.from_address_hash == address_hash

        _ ->
          internal_transaction.to_address_hash == address_hash or
            internal_transaction.from_address_hash == address_hash or
            internal_transaction.created_contract_address_hash == address_hash
      end
    end)
  end

  defp fetch_block_internal_transactions(block_numbers, options) do
    if internal_transactions_fetching_disabled?() do
      []
    else
      {_status, internal_transactions_params} = trace_blocks(block_numbers, options)
      internal_transactions_params
    end
  end

  # Returns `{:error, internal_transactions_params}` with the traced part when some of the blocks fail to be traced
  defp trace_blocks(block_numbers, options) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

    if variant in InternalTransactionFetcher.block_traceable_variants() do
      fetch_blocks_internal_transactions(block_numbers, json_rpc_named_arguments)
    else
      block_numbers
      |> transactions_to_trace(options)
      |> fetch_transactions_internal_transactions(json_rpc_named_arguments)
    end
  end

  # Traces blocks in batches of `blocks_batch_size()` sent in parallel. Any
  # failed batch fails the whole fetch (as a failed batch did before batching
  # was introduced) to avoid silent gaps in paginated results.
  defp fetch_blocks_internal_transactions(block_numbers, json_rpc_named_arguments) do
    chunk_results =
      block_numbers
      |> Enum.chunk_every(blocks_batch_size())
      |> Task.async_stream(
        fn chunk -> {chunk, EthereumJSONRPC.fetch_block_internal_transactions(chunk, json_rpc_named_arguments)} end,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, chunk_result} -> chunk_result end)

    if Enum.all?(chunk_results, &match?({_chunk, {:ok, _}}, &1)) do
      {:ok, Enum.flat_map(chunk_results, fn {_chunk, {:ok, result}} -> result end)}
    else
      Enum.each(chunk_results, fn
        {_chunk, {:ok, _}} ->
          :ok

        {chunk, error} ->
          Logger.error("Failed to fetch internal transactions for blocks #{inspect(chunk)}: #{inspect(error)}")
      end)

      {:error, []}
    end
  end

  # Collects traceable transactions of all the blocks with a single DB query,
  # preserving the order of `block_numbers` (and transaction index order within
  # a block).
  defp transactions_to_trace(block_numbers, options) do
    transactions_by_block_number =
      block_numbers
      |> Transaction.get_transactions_of_block_numbers(options)
      |> Transaction.filter_non_traceable_transactions()
      |> Enum.group_by(& &1.block_number)

    Enum.flat_map(block_numbers, fn block_number ->
      transactions_by_block_number
      |> Map.get(block_number, [])
      |> Enum.sort_by(& &1.index)
      |> Enum.map(
        &%{
          block_number: &1.block_number,
          hash_data: to_string(&1.hash),
          transaction_index: &1.index
        }
      )
    end)
  end

  # Traces transactions in cross-block batches of `transactions_batch_size()`
  # sent in parallel, instead of one batch per block. A failed batch is skipped
  # with a log, the same way a failed per-block batch was skipped before, and
  # the result is `{:error, internal_transactions_of_other_batches}`.
  defp fetch_transactions_internal_transactions(transactions, json_rpc_named_arguments) do
    transactions
    |> Enum.chunk_every(transactions_batch_size())
    |> Task.async_stream(
      fn chunk -> {chunk, do_fetch_transactions_internal_transactions(chunk, json_rpc_named_arguments)} end,
      timeout: :infinity
    )
    |> Enum.reduce({:ok, []}, fn
      {:ok, {_chunk, {:ok, internal_transactions}}}, {status, acc} ->
        {status, [internal_transactions | acc]}

      {:ok, {chunk, error_or_ignore}}, {_status, acc} ->
        Logger.error(
          "Failed to fetch internal transactions for transactions #{inspect(Enum.map(chunk, & &1.hash_data))}: #{inspect(error_or_ignore)}"
        )

        {:error, acc}
    end)
    |> then(fn {status, internal_transactions_chunks} ->
      {status, internal_transactions_chunks |> Enum.reverse() |> Enum.concat()}
    end)
  end

  defp do_fetch_transactions_internal_transactions(chunk, json_rpc_named_arguments) do
    EthereumJSONRPC.fetch_internal_transactions(chunk, json_rpc_named_arguments)
  catch
    :exit, error ->
      {:error, error, __STACKTRACE__}
  end

  defp blocks_batch_size do
    Application.get_env(:indexer, __MODULE__, [])[:blocks_batch_size] || @default_blocks_batch_size
  end

  defp transactions_batch_size do
    Application.get_env(:indexer, __MODULE__, [])[:transactions_batch_size] || @default_transactions_batch_size
  end

  defp internal_transactions_fetching_disabled? do
    Application.get_env(:indexer, __MODULE__, [])[:disabled?] == true
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

  defp join_associations(records, necessity_by_association, options)
       when is_list(records) and is_map(necessity_by_association) do
    Enum.reduce(necessity_by_association, records, fn {association, necessity}, acc ->
      join_association(acc, association, necessity, options)
    end)
  end

  defp join_association(records, [{association, nested_preload}], :optional, options)
       when is_atom(association) do
    Chain.select_repo(options).preload(records, [{association, nested_preload}])
  end

  defp join_association(records, [{association, nested_preload}], :required, options)
       when is_atom(association) do
    records
    |> Chain.select_repo(options).preload([{association, nested_preload}])
    |> Enum.filter(fn struct ->
      case Map.fetch(struct, association) do
        {:ok, value} -> not is_nil(value)
        :error -> true
      end
    end)
  end

  defp join_association(records, association, :optional, options) do
    Chain.select_repo(options).preload(records, association)
  end

  defp join_association(records, association, :required, options) do
    records
    |> Chain.select_repo(options).preload(association)
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

  defp different_from_parent_transaction(internal_transactions) do
    Enum.reject(internal_transactions, &(&1.type == :call and &1.index == 0))
  end

  # Works like `Explorer.Chain.InternalTransaction.include_zero_value/2`: calls without a positive value are rejected
  # when the `include_zero_value` option is false
  defp filter_zero_value(internal_transactions, options) do
    if Keyword.get(options, :include_zero_value, true) do
      internal_transactions
    else
      Enum.reject(internal_transactions, &zero_value_call?/1)
    end
  end

  defp zero_value_call?(%InternalTransaction{type: :call, value: %Wei{value: value}}), do: not Decimal.gt?(value, 0)
  defp zero_value_call?(%InternalTransaction{type: :call}), do: true
  defp zero_value_call?(_internal_transaction), do: false

  defp serialize(internal_transaction_params) do
    to_address_hash = convert_to_address_hash(internal_transaction_params[:to_address_hash])
    created_contract_address_hash = convert_to_address_hash(internal_transaction_params[:created_contract_address_hash])

    %InternalTransaction{}
    |> InternalTransaction.changeset(internal_transaction_params)
    |> Ecto.Changeset.apply_changes()
    |> Map.put(:transaction_hash, internal_transaction_params[:transaction_hash])
    |> Map.put(:from_address_hash, convert_to_address_hash(internal_transaction_params[:from_address_hash]))
    |> Map.put(:to_address_hash, to_address_hash || created_contract_address_hash)
    |> Map.put(:created_contract_address_hash, created_contract_address_hash)
  end

  defp convert_to_address_hash(nil), do: nil

  defp convert_to_address_hash(hash_string) do
    {:ok, hash} = Hash.Address.cast(hash_string)
    hash
  end

  # Etherscan-compatible API pages are numbered, while the node is queried for the internal transactions starting
  # from the first one: all the items up to the requested page are fetched, and `etherscan_page/2` cuts the page out.
  # `page_number * page_size` is limited by the API's results window.
  defp etherscan_paging_options(%{page_number: page_number, page_size: page_size}) do
    %PagingOptions{page_size: page_number * page_size}
  end

  defp etherscan_page(internal_transactions, %{page_number: page_number, page_size: page_size}) do
    internal_transactions
    |> Enum.drop((page_number - 1) * page_size)
    |> Enum.take(page_size)
  end

  defp etherscan_serialize(internal_transaction) do
    internal_transaction_fields =
      Etherscan.internal_transaction_fields() ++
        [:transaction_hash, :from_address_hash, :to_address_hash, :created_contract_address_hash, :error]

    internal_transaction
    |> Map.take(internal_transaction_fields)
    |> Map.put(:block_timestamp, internal_transaction.block.timestamp)
  end
end
