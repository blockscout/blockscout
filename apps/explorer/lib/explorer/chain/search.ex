defmodule Explorer.Chain.Search do
  @moduledoc """
    Search related functions
  """
  import Ecto.Query,
    only: [
      dynamic: 2,
      from: 2,
      limit: 2,
      order_by: 3,
      subquery: 1,
      union: 2,
      where: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]
  import Explorer.MicroserviceInterfaces.BENS, only: [ens_domain_name_lookup: 1]
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.Tags.{AddressTag, AddressToTag}

  alias Explorer.Chain.{
    Address,
    Beacon.Blob,
    Block,
    DenormalizationHelper,
    SmartContract,
    Token,
    Transaction,
    UserOperation
  }

  @doc """
    Search function used in web interface. Returns paginated search results
  """
  @spec joint_search(PagingOptions.t(), integer(), binary(), [Chain.api?()] | []) :: list
  def joint_search(paging_options, offset, raw_string, options \\ []) do
    string = String.trim(raw_string)

    ens_task = maybe_run_ens_task(paging_options, raw_string, options)

    result =
      case prepare_search_term(string) do
        {:some, term} ->
          query = base_joint_query(string, term)

          ordered_query =
            from(items in subquery(query),
              order_by: [
                desc: items.priority,
                desc_nulls_last: items.certified,
                desc_nulls_last: items.circulating_market_cap,
                desc_nulls_last: items.exchange_rate,
                desc_nulls_last: items.is_verified_via_admin_panel,
                desc_nulls_last: items.holder_count,
                asc: items.name,
                desc: items.inserted_at
              ],
              limit: ^paging_options.page_size,
              offset: ^offset
            )

          paginated_ordered_query =
            ordered_query
            |> page_search_results(paging_options)

          search_results = select_repo(options).all(paginated_ordered_query)

          search_results
          |> Enum.map(fn result ->
            result
            |> compose_result_checksummed_address_hash()
            |> format_timestamp()
          end)

        _ ->
          []
      end

    ens_result = (ens_task && await_ens_task(ens_task)) || []

    ens_result ++ result
  end

  def base_joint_query(string, term) do
    tokens_query =
      string |> search_token_query(term) |> ExplorerHelper.maybe_hide_scam_addresses(:contract_address_hash)

    contracts_query = term |> search_contract_query() |> ExplorerHelper.maybe_hide_scam_addresses(:address_hash)
    labels_query = search_label_query(term)
    address_query = string |> search_address_query() |> ExplorerHelper.maybe_hide_scam_addresses(:hash)
    block_query = search_block_query(string)

    basic_query =
      from(
        tokens in subquery(tokens_query),
        union: ^contracts_query,
        union: ^labels_query
      )

    cond do
      address_query ->
        basic_query
        |> union(^address_query)

      valid_full_hash?(string) ->
        tx_query = search_tx_query(string)

        tx_block_query =
          basic_query
          |> union(^tx_query)
          |> union(^block_query)

        tx_block_op_query =
          if UserOperation.enabled?() do
            user_operation_query = search_user_operation_query(string)

            tx_block_query
            |> union(^user_operation_query)
          else
            tx_block_query
          end

        if Application.get_env(:explorer, :chain_type) == :ethereum do
          blob_query = search_blob_query(string)

          tx_block_op_query
          |> union(^blob_query)
        else
          tx_block_op_query
        end

      block_query ->
        basic_query
        |> union(^block_query)

      true ->
        basic_query
    end
  end

  defp maybe_run_ens_task(%PagingOptions{key: nil}, query_string, options) do
    Task.async(fn -> search_ens_name(query_string, options) end)
  end

  defp maybe_run_ens_task(_, _query_string, _options), do: nil

  @doc """
    Search function. Differences from joint_search/4:
      1. Returns all the found categories (amount of results up to `paging_options.page_size`).
          For example if was found 50 tokens, 50 smart-contracts, 50 labels, 1 address, 1 transaction and 2 blocks (impossible, just example) and page_size=50. Then function will return:
            [1 address, 1 transaction, 2 blocks, 16 tokens, 15 smart-contracts, 15 labels]
      2. Results couldn't be paginated
  """
  @spec balanced_unpaginated_search(PagingOptions.t(), binary(), [Chain.api?()] | []) :: list
  # credo:disable-for-next-line
  def balanced_unpaginated_search(paging_options, raw_search_query, options \\ []) do
    search_query = String.trim(raw_search_query)
    ens_task = Task.async(fn -> search_ens_name(raw_search_query, options) end)

    case prepare_search_term(search_query) do
      {:some, term} ->
        tokens_result =
          search_query
          |> search_token_query(term)
          |> ExplorerHelper.maybe_hide_scam_addresses(:contract_address_hash)
          |> order_by([token],
            desc_nulls_last: token.circulating_market_cap,
            desc_nulls_last: token.fiat_value,
            desc_nulls_last: token.is_verified_via_admin_panel,
            desc_nulls_last: token.holder_count,
            asc: token.name,
            desc: token.inserted_at
          )
          |> limit(^paging_options.page_size)
          |> select_repo(options).all()

        contracts_result =
          term
          |> search_contract_query()
          |> ExplorerHelper.maybe_hide_scam_addresses(:address_hash)
          |> order_by([items], asc: items.name, desc: items.inserted_at)
          |> limit(^paging_options.page_size)
          |> select_repo(options).all()

        labels_result =
          term
          |> search_label_query()
          |> order_by([att, at], asc: at.display_name, desc: att.inserted_at)
          |> limit(^paging_options.page_size)
          |> select_repo(options).all()

        tx_result =
          if valid_full_hash?(search_query) do
            search_query
            |> search_tx_query()
            |> select_repo(options).all()
          else
            []
          end

        op_result =
          if valid_full_hash?(search_query) && UserOperation.enabled?() do
            search_query
            |> search_user_operation_query()
            |> select_repo(options).all()
          else
            []
          end

        blob_result =
          if valid_full_hash?(search_query) && Application.get_env(:explorer, :chain_type) == :ethereum do
            search_query
            |> search_blob_query()
            |> select_repo(options).all()
          else
            []
          end

        address_result =
          if query = search_address_query(search_query) do
            query
            |> ExplorerHelper.maybe_hide_scam_addresses(:hash)
            |> select_repo(options).all()
          else
            []
          end

        blocks_result =
          if query = search_block_query(search_query) do
            query
            |> limit(^paging_options.page_size)
            |> select_repo(options).all()
          else
            []
          end

        ens_result = await_ens_task(ens_task)

        non_empty_lists =
          [
            tokens_result,
            contracts_result,
            labels_result,
            tx_result,
            op_result,
            blob_result,
            address_result,
            blocks_result,
            ens_result
          ]
          |> Enum.filter(fn list -> not Enum.empty?(list) end)
          |> Enum.sort_by(fn list -> Enum.count(list) end, :asc)

        to_take =
          non_empty_lists
          |> Enum.map(fn list -> Enum.count(list) end)
          |> take_all_categories(List.duplicate(0, Enum.count(non_empty_lists)), paging_options.page_size)

        non_empty_lists
        |> Enum.zip_reduce(to_take, [], fn x, y, acc -> acc ++ Enum.take(x, y) end)
        |> Enum.map(fn result ->
          result
          |> compose_result_checksummed_address_hash()
          |> format_timestamp()
        end)
        |> Enum.sort_by(fn item -> item.priority end, :desc)

      _ ->
        []
    end
  end

  defp await_ens_task(ens_task) do
    case Task.yield(ens_task, 5000) || Task.shutdown(ens_task) do
      {:ok, result} ->
        result

      _ ->
        []
    end
  end

  def prepare_search_term(string) do
    case Regex.scan(~r/[a-zA-Z0-9]+/, string) do
      [_ | _] = words ->
        term_final =
          words
          |> Enum.map_join(" & ", fn [word] -> word <> ":*" end)

        {:some, term_final}

      _ ->
        :none
    end
  end

  defp search_label_query(term) do
    label_search_fields =
      search_fields()
      |> Map.put(:address_hash, dynamic([att, _, _], att.address_hash))
      |> Map.put(:type, "label")
      |> Map.put(:name, dynamic([_, at, _], at.display_name))
      |> Map.put(:inserted_at, dynamic([att, _, _], att.inserted_at))
      |> Map.put(:verified, dynamic([_, _, smart_contract], not is_nil(smart_contract)))
      |> Map.put(:priority, 1)

    inner_query =
      from(tag in AddressTag,
        where: fragment("to_tsvector('english', ?) @@ to_tsquery(?)", tag.display_name, ^term),
        select: tag
      )

    from(att in AddressToTag,
      inner_join: at in subquery(inner_query),
      on: att.tag_id == at.id,
      left_join: smart_contract in SmartContract,
      on: att.address_hash == smart_contract.address_hash,
      select: ^label_search_fields
    )
  end

  defp search_token_query(string, term) do
    token_search_fields =
      search_fields()
      |> Map.put(:address_hash, dynamic([token, _], token.contract_address_hash))
      |> Map.put(:type, "token")
      |> Map.put(:name, dynamic([token, _], token.name))
      |> Map.put(:symbol, dynamic([token, _], token.symbol))
      |> Map.put(:holder_count, dynamic([token, _], token.holder_count))
      |> Map.put(:inserted_at, dynamic([token, _], token.inserted_at))
      |> Map.put(:icon_url, dynamic([token, _], token.icon_url))
      |> Map.put(:token_type, dynamic([token, _], token.type))
      |> Map.put(:verified, dynamic([_, smart_contract], not is_nil(smart_contract)))
      |> Map.put(:certified, dynamic([_, smart_contract], smart_contract.certified))
      |> Map.put(:exchange_rate, dynamic([token, _], token.fiat_value))
      |> Map.put(:total_supply, dynamic([token, _], token.total_supply))
      |> Map.put(:circulating_market_cap, dynamic([token, _], token.circulating_market_cap))
      |> Map.put(:is_verified_via_admin_panel, dynamic([token, _], token.is_verified_via_admin_panel))

    case Chain.string_to_address_hash(string) do
      {:ok, address_hash} ->
        from(token in Token,
          left_join: smart_contract in SmartContract,
          on: token.contract_address_hash == smart_contract.address_hash,
          where: token.contract_address_hash == ^address_hash,
          select: ^token_search_fields
        )

      _ ->
        from(token in Token,
          left_join: smart_contract in SmartContract,
          on: token.contract_address_hash == smart_contract.address_hash,
          where: fragment("to_tsvector('english', ? || ' ' || ?) @@ to_tsquery(?)", token.symbol, token.name, ^term),
          select: ^token_search_fields
        )
    end
  end

  defp search_contract_query(term) do
    contract_search_fields =
      search_fields()
      |> Map.put(:address_hash, dynamic([smart_contract, _], smart_contract.address_hash))
      |> Map.put(:type, "contract")
      |> Map.put(:name, dynamic([smart_contract, _], smart_contract.name))
      |> Map.put(:inserted_at, dynamic([_, address], address.inserted_at))
      |> Map.put(:certified, dynamic([smart_contract, _], smart_contract.certified))
      |> Map.put(:verified, true)

    from(smart_contract in SmartContract,
      left_join: address in Address,
      on: smart_contract.address_hash == address.hash,
      where: fragment("to_tsvector('english', ?) @@ to_tsquery(?)", smart_contract.name, ^term),
      select: ^contract_search_fields
    )
  end

  defp search_address_query(term) do
    case Chain.string_to_address_hash(term) do
      {:ok, address_hash} ->
        address_search_fields =
          search_fields()
          |> Map.put(:address_hash, dynamic([address, _, _], address.hash))
          |> Map.put(:type, "address")
          |> Map.put(:name, dynamic([_, address_name, _], address_name.name))
          |> Map.put(:inserted_at, dynamic([_, address_name, _], address_name.inserted_at))
          |> Map.put(:verified, dynamic([address, _, _], address.verified))
          |> Map.put(:certified, dynamic([_, _, smart_contract], smart_contract.certified))

        from(address in Address,
          left_join:
            address_name in subquery(
              from(name in Address.Name,
                where: name.address_hash == ^address_hash,
                order_by: [desc: name.primary],
                limit: 1
              )
            ),
          on: address.hash == address_name.address_hash,
          left_join: smart_contract in SmartContract,
          on: address.hash == smart_contract.address_hash,
          where: address.hash == ^address_hash,
          select: ^address_search_fields
        )

      _ ->
        nil
    end
  end

  defp valid_full_hash?(string_input) do
    case Chain.string_to_transaction_hash(string_input) do
      {:ok, _tx_hash} -> true
      _ -> false
    end
  end

  defp search_tx_query(term) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      transaction_search_fields =
        search_fields()
        |> Map.put(:tx_hash, dynamic([transaction], transaction.hash))
        |> Map.put(:block_hash, dynamic([transaction], transaction.block_hash))
        |> Map.put(:type, "transaction")
        |> Map.put(:block_number, dynamic([transaction], transaction.block_number))
        |> Map.put(:inserted_at, dynamic([transaction], transaction.inserted_at))
        |> Map.put(:timestamp, dynamic([transaction], transaction.block_timestamp))

      from(transaction in Transaction,
        where: transaction.hash == ^term,
        select: ^transaction_search_fields
      )
    else
      transaction_search_fields =
        search_fields()
        |> Map.put(:tx_hash, dynamic([transaction, _], transaction.hash))
        |> Map.put(:block_hash, dynamic([transaction, _], transaction.block_hash))
        |> Map.put(:type, "transaction")
        |> Map.put(:block_number, dynamic([transaction, _], transaction.block_number))
        |> Map.put(:inserted_at, dynamic([transaction, _], transaction.inserted_at))
        |> Map.put(:timestamp, dynamic([_, block], block.timestamp))

      from(transaction in Transaction,
        left_join: block in Block,
        on: transaction.block_hash == block.hash,
        where: transaction.hash == ^term,
        select: ^transaction_search_fields
      )
    end
  end

  defp search_user_operation_query(term) do
    user_operation_search_fields =
      search_fields()
      |> Map.put(:user_operation_hash, dynamic([user_operation, _], user_operation.hash))
      |> Map.put(:block_hash, dynamic([user_operation, _], user_operation.block_hash))
      |> Map.put(:type, "user_operation")
      |> Map.put(:inserted_at, dynamic([user_operation, _], user_operation.inserted_at))
      |> Map.put(:block_number, dynamic([user_operation, _], user_operation.block_number))
      |> Map.put(:timestamp, dynamic([_, block], block.timestamp))

    from(user_operation in UserOperation,
      left_join: block in Block,
      on: user_operation.block_hash == block.hash,
      where: user_operation.hash == ^term,
      select: ^user_operation_search_fields
    )
  end

  defp search_blob_query(term) do
    blob_search_fields =
      search_fields()
      |> Map.put(:blob_hash, dynamic([blob, _], blob.hash))
      |> Map.put(:type, "blob")
      |> Map.put(:inserted_at, dynamic([blob, _], blob.inserted_at))

    from(blob in Blob,
      where: blob.hash == ^term,
      select: ^blob_search_fields
    )
  end

  defp search_block_query(term) do
    block_search_fields =
      search_fields()
      |> Map.put(:block_hash, dynamic([block], block.hash))
      |> Map.put(:type, "block")
      |> Map.put(:block_number, dynamic([block], block.number))
      |> Map.put(:inserted_at, dynamic([block], block.inserted_at))
      |> Map.put(:timestamp, dynamic([block], block.timestamp))

    case Chain.string_to_block_hash(term) do
      {:ok, block_hash} ->
        from(block in Block,
          where: block.hash == ^block_hash,
          select: ^block_search_fields
        )

      _ ->
        case ExplorerHelper.safe_parse_non_negative_integer(term) do
          {:ok, block_number} ->
            from(block in Block,
              where: block.number == ^block_number,
              select: ^block_search_fields
            )

          _ ->
            nil
        end
    end
  end

  defp page_search_results(query, %PagingOptions{key: nil}), do: query

  defp page_search_results(query, %PagingOptions{
         key: {_address_hash, _tx_hash, _block_hash, holder_count, name, inserted_at, item_type}
       })
       when holder_count in [nil, ""] do
    where(
      query,
      [item],
      (item.name > ^name and item.type == ^item_type) or
        (item.name == ^name and item.inserted_at < ^inserted_at and
           item.type == ^item_type) or
        item.type != ^item_type
    )
  end

  # credo:disable-for-next-line
  defp page_search_results(query, %PagingOptions{
         key: {_address_hash, _tx_hash, _block_hash, holder_count, name, inserted_at, item_type}
       }) do
    where(
      query,
      [item],
      (item.holder_count < ^holder_count and item.type == ^item_type) or
        (item.holder_count == ^holder_count and item.name > ^name and item.type == ^item_type) or
        (item.holder_count == ^holder_count and item.name == ^name and item.inserted_at < ^inserted_at and
           item.type == ^item_type) or
        item.type != ^item_type
    )
  end

  defp take_all_categories([], taken_lengths, _remained), do: taken_lengths

  defp take_all_categories(lengths, taken_lengths, remained) do
    non_zero_count = count_non_zero(lengths)

    target = if(remained < non_zero_count, do: 1, else: div(remained, non_zero_count))

    {lengths_updated, %{result: taken_lengths_reversed}} =
      Enum.map_reduce(lengths, %{result: [], sum: 0}, fn el, acc ->
        taken =
          cond do
            acc[:sum] >= remained ->
              0

            el < target ->
              el

            true ->
              target
          end

        {el - taken, %{result: [taken | acc[:result]], sum: acc[:sum] + taken}}
      end)

    taken_lengths =
      taken_lengths
      |> Enum.zip_reduce(Enum.reverse(taken_lengths_reversed), [], fn x, y, acc -> [x + y | acc] end)
      |> Enum.reverse()

    remained = remained - Enum.sum(taken_lengths_reversed)

    if remained > 0 and count_non_zero(lengths_updated) > 0 do
      take_all_categories(lengths_updated, taken_lengths, remained)
    else
      taken_lengths
    end
  end

  defp count_non_zero(list) do
    Enum.reduce(list, 0, fn el, acc -> acc + if el > 0, do: 1, else: 0 end)
  end

  defp compose_result_checksummed_address_hash(result) do
    if result.address_hash do
      result
      |> Map.put(:address_hash, Address.checksum(result.address_hash))
    else
      result
    end
  end

  # For some reasons timestamp for blocks and txs returns as ~N[2023-06-25 19:39:47.339493]
  defp format_timestamp(result) do
    if result.timestamp do
      result
      |> Map.put(:timestamp, DateTime.from_naive!(result.timestamp, "Etc/UTC"))
    else
      result
    end
  end

  defp search_ens_name(search_query, options) do
    if result = search_ens_name_in_bens(search_query) do
      [
        result[:address_hash]
        |> search_address_query()
        |> ExplorerHelper.maybe_hide_scam_addresses(:hash)
        |> select_repo(options).all()
        |> merge_address_search_result_with_ens_info(result)
      ]
    else
      []
    end
  end

  @doc """
  Try to resolve ENS domain via BENS
  """
  @spec search_ens_name_in_bens(binary()) ::
          nil | %{address_hash: binary(), expiry_date: any(), name: any(), names_count: non_neg_integer()}
  def search_ens_name_in_bens(search_query) do
    trimmed_query = String.trim(search_query)

    with true <- Regex.match?(~r/\w+\.\w+/, trimmed_query),
         %{address_hash: _address_hash} = result <- ens_domain_name_lookup(search_query) do
      result
    else
      _ ->
        nil
    end
  end

  defp merge_address_search_result_with_ens_info([], ens_info) do
    search_fields()
    |> Map.put(:address_hash, ens_info[:address_hash])
    |> Map.put(:type, "ens_domain")
    |> Map.put(:ens_info, ens_info)
    |> Map.put(:timestamp, nil)
    |> Map.put(:priority, 2)
  end

  defp merge_address_search_result_with_ens_info([address], ens_info) do
    address
    |> compose_result_checksummed_address_hash()
    |> Map.put(:type, "ens_domain")
    |> Map.put(:ens_info, ens_info)
    |> Map.put(:priority, 2)
  end

  defp search_fields do
    %{
      address_hash: dynamic([_], type(^nil, :binary)),
      tx_hash: dynamic([_], type(^nil, :binary)),
      user_operation_hash: dynamic([_], type(^nil, :binary)),
      blob_hash: dynamic([_], type(^nil, :binary)),
      block_hash: dynamic([_], type(^nil, :binary)),
      type: nil,
      name: nil,
      symbol: nil,
      holder_count: nil,
      inserted_at: nil,
      block_number: 0,
      icon_url: nil,
      token_type: nil,
      timestamp: dynamic([_, _], type(^nil, :utc_datetime_usec)),
      verified: nil,
      certified: nil,
      exchange_rate: nil,
      total_supply: nil,
      circulating_market_cap: nil,
      priority: 0,
      is_verified_via_admin_panel: nil
    }
  end
end
