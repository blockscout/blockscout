defmodule Explorer.Chain.Search do
  @moduledoc """
    Search related functions
  """
  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 3,
      subquery: 1,
      union: 2,
      where: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Tags.{AddressTag, AddressToTag}

  alias Explorer.Chain.{
    Address,
    Block,
    SmartContract,
    Token,
    Transaction
  }

  @doc """
    Search function used in web interface. Returns paginated search results
  """
  @spec joint_search(PagingOptions.t(), integer(), binary(), [Chain.api?()] | []) :: list
  def joint_search(paging_options, offset, raw_string, options \\ []) do
    string = String.trim(raw_string)

    case prepare_search_term(string) do
      {:some, term} ->
        tokens_query = search_token_query(term)
        contracts_query = search_contract_query(term)
        labels_query = search_label_query(term)
        tx_query = search_tx_query(string)
        address_query = search_address_query(string)
        block_query = search_block_query(string)

        basic_query =
          from(
            tokens in subquery(tokens_query),
            union: ^contracts_query,
            union: ^labels_query
          )

        query =
          cond do
            address_query ->
              basic_query
              |> union(^address_query)

            tx_query ->
              basic_query
              |> union(^tx_query)
              |> union(^block_query)

            block_query ->
              basic_query
              |> union(^block_query)

            true ->
              basic_query
          end

        ordered_query =
          from(items in subquery(query),
            order_by: [
              desc: items.priority,
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
  end

  @doc """
    Search function. Differences from joint_search/4:
      1. Returns all the found categories (amount of results up to `paging_options.page_size`).
          For example if was found 50 tokens, 50 smart-contracts, 50 labels, 1 address, 1 transaction and 2 blocks (impossible, just example) and page_size=50. Then function will return:
            [1 address, 1 transaction, 2 blocks, 16 tokens, 15 smart-contracts, 15 labels]
      2. Results couldn't be paginated
  """
  @spec balanced_unpaginated_search(PagingOptions.t(), binary(), [Chain.api?()] | []) :: list
  def balanced_unpaginated_search(paging_options, raw_search_query, options \\ []) do
    search_query = String.trim(raw_search_query)

    case prepare_search_term(search_query) do
      {:some, term} ->
        tokens_result =
          term
          |> search_token_query()
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
          if query = search_tx_query(search_query) do
            query
            |> select_repo(options).all()
          else
            []
          end

        address_result =
          if query = search_address_query(search_query) do
            query
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

        non_empty_lists =
          [tokens_result, contracts_result, labels_result, tx_result, address_result, blocks_result]
          |> Enum.filter(fn list -> Enum.count(list) > 0 end)
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
      select: %{
        address_hash: att.address_hash,
        tx_hash: fragment("CAST(NULL AS bytea)"),
        block_hash: fragment("CAST(NULL AS bytea)"),
        type: "label",
        name: at.display_name,
        symbol: ^nil,
        holder_count: ^nil,
        inserted_at: att.inserted_at,
        block_number: 0,
        icon_url: nil,
        token_type: nil,
        timestamp: fragment("NULL::timestamp without time zone"),
        verified: not is_nil(smart_contract),
        exchange_rate: nil,
        total_supply: nil,
        circulating_market_cap: nil,
        priority: 1,
        is_verified_via_admin_panel: nil
      }
    )
  end

  defp search_token_query(term) do
    from(token in Token,
      left_join: smart_contract in SmartContract,
      on: token.contract_address_hash == smart_contract.address_hash,
      where: fragment("to_tsvector('english', ? || ' ' || ?) @@ to_tsquery(?)", token.symbol, token.name, ^term),
      select: %{
        address_hash: token.contract_address_hash,
        tx_hash: fragment("CAST(NULL AS bytea)"),
        block_hash: fragment("CAST(NULL AS bytea)"),
        type: "token",
        name: token.name,
        symbol: token.symbol,
        holder_count: token.holder_count,
        inserted_at: token.inserted_at,
        block_number: 0,
        icon_url: token.icon_url,
        token_type: token.type,
        timestamp: fragment("NULL::timestamp without time zone"),
        verified: not is_nil(smart_contract),
        exchange_rate: token.fiat_value,
        total_supply: token.total_supply,
        circulating_market_cap: token.circulating_market_cap,
        priority: 0,
        is_verified_via_admin_panel: token.is_verified_via_admin_panel
      }
    )
  end

  defp search_contract_query(term) do
    from(smart_contract in SmartContract,
      left_join: address in Address,
      on: smart_contract.address_hash == address.hash,
      where: fragment("to_tsvector('english', ?) @@ to_tsquery(?)", smart_contract.name, ^term),
      select: %{
        address_hash: smart_contract.address_hash,
        tx_hash: fragment("CAST(NULL AS bytea)"),
        block_hash: fragment("CAST(NULL AS bytea)"),
        type: "contract",
        name: smart_contract.name,
        symbol: ^nil,
        holder_count: ^nil,
        inserted_at: address.inserted_at,
        block_number: 0,
        icon_url: nil,
        token_type: nil,
        timestamp: fragment("NULL::timestamp without time zone"),
        verified: true,
        exchange_rate: nil,
        total_supply: nil,
        circulating_market_cap: nil,
        priority: 0,
        is_verified_via_admin_panel: nil
      }
    )
  end

  defp search_address_query(term) do
    case Chain.string_to_address_hash(term) do
      {:ok, address_hash} ->
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
          where: address.hash == ^address_hash,
          select: %{
            address_hash: address.hash,
            tx_hash: fragment("CAST(NULL AS bytea)"),
            block_hash: fragment("CAST(NULL AS bytea)"),
            type: "address",
            name: address_name.name,
            symbol: ^nil,
            holder_count: ^nil,
            inserted_at: address.inserted_at,
            block_number: 0,
            icon_url: nil,
            token_type: nil,
            timestamp: fragment("NULL::timestamp without time zone"),
            verified: address.verified,
            exchange_rate: nil,
            total_supply: nil,
            circulating_market_cap: nil,
            priority: 0,
            is_verified_via_admin_panel: nil
          }
        )

      _ ->
        nil
    end
  end

  defp search_tx_query(term) do
    case Chain.string_to_transaction_hash(term) do
      {:ok, tx_hash} ->
        from(transaction in Transaction,
          left_join: block in Block,
          on: transaction.block_hash == block.hash,
          where: transaction.hash == ^tx_hash,
          select: %{
            address_hash: fragment("CAST(NULL AS bytea)"),
            tx_hash: transaction.hash,
            block_hash: fragment("CAST(NULL AS bytea)"),
            type: "transaction",
            name: ^nil,
            symbol: ^nil,
            holder_count: ^nil,
            inserted_at: transaction.inserted_at,
            block_number: 0,
            icon_url: nil,
            token_type: nil,
            timestamp: block.timestamp,
            verified: nil,
            exchange_rate: nil,
            total_supply: nil,
            circulating_market_cap: nil,
            priority: 0,
            is_verified_via_admin_panel: nil
          }
        )

      _ ->
        nil
    end
  end

  defp search_block_query(term) do
    case Chain.string_to_block_hash(term) do
      {:ok, block_hash} ->
        from(block in Block,
          where: block.hash == ^block_hash,
          select: %{
            address_hash: fragment("CAST(NULL AS bytea)"),
            tx_hash: fragment("CAST(NULL AS bytea)"),
            block_hash: block.hash,
            type: "block",
            name: ^nil,
            symbol: ^nil,
            holder_count: ^nil,
            inserted_at: block.inserted_at,
            block_number: block.number,
            icon_url: nil,
            token_type: nil,
            timestamp: block.timestamp,
            verified: nil,
            exchange_rate: nil,
            total_supply: nil,
            circulating_market_cap: nil,
            priority: 0,
            is_verified_via_admin_panel: nil
          }
        )

      _ ->
        case Integer.parse(term) do
          {block_number, ""} ->
            from(block in Block,
              where: block.number == ^block_number,
              select: %{
                address_hash: fragment("CAST(NULL AS bytea)"),
                tx_hash: fragment("CAST(NULL AS bytea)"),
                block_hash: block.hash,
                type: "block",
                name: ^nil,
                symbol: ^nil,
                holder_count: ^nil,
                inserted_at: block.inserted_at,
                block_number: block.number,
                icon_url: nil,
                token_type: nil,
                timestamp: block.timestamp,
                verified: nil,
                exchange_rate: nil,
                total_supply: nil,
                circulating_market_cap: nil,
                priority: 0,
                is_verified_via_admin_panel: nil
              }
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
end
