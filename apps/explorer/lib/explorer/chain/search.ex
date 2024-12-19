defmodule Explorer.Chain.Search do
  @moduledoc """
    Search-related functions
  """
  import Ecto.Query
  import Explorer.Chain, only: [select_repo: 1]
  import Explorer.MicroserviceInterfaces.BENS, only: [ens_domain_name_lookup: 1]

  import Explorer.PagingOptions,
    only: [
      default_paging_options: 0
    ]

  import Explorer.SortingHelper, only: [apply_sorting: 3, page_with_sorting: 4]

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.Tags.{AddressTag, AddressToTag}

  alias Explorer.Chain.{
    Address,
    Beacon.Blob,
    Block,
    DenormalizationHelper,
    Hash,
    SmartContract,
    Token,
    Transaction,
    UserOperation
  }

  @min_query_length 3

  @token_sorting [
    {:desc_nulls_last, :circulating_market_cap, :token},
    {:desc_nulls_last, :fiat_value, :token},
    {:desc_nulls_last, :is_verified_via_admin_panel, :token},
    {:desc_nulls_last, :holder_count, :token},
    {:asc, :name, :token},
    {:desc, :inserted_at, :token}
  ]

  @contract_sorting [
    {:desc_nulls_last, :certified, :smart_contract},
    {:asc, :name, :smart_contract},
    {:desc, :inserted_at, :smart_contract}
  ]

  @label_sorting [{:asc, :display_name, :address_tag}, {:desc, :inserted_at, :address_to_tag}]

  @doc """
  Search function used in web interface and API v2. Returns paginated search results
  """
  @spec joint_search(PagingOptions.t(), binary(), [Chain.api?()] | []) :: {list(), map() | nil}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def joint_search(paging_options, query_string, options \\ []) do
    query_string = String.trim(query_string)
    ens_task = run_ens_task_if_first_page(paging_options, query_string, options)

    search_results =
      query_string
      |> prepare_search_query(prepare_search_term(query_string))
      |> case do
        nil ->
          []

        {:address_hash, address_hash} ->
          address_hash
          |> search_token_by_address_hash_query()
          |> ExplorerHelper.maybe_hide_scam_addresses(:contract_address_hash)
          |> union_all(
            ^(address_hash
              |> search_address_by_address_hash_query()
              |> ExplorerHelper.maybe_hide_scam_addresses(:hash))
          )
          |> select_repo(options).all()

        {:full_hash, full_hash} ->
          transaction_block_query =
            full_hash
            |> search_transaction_query()
            |> union_all(^search_block_by_hash_query(full_hash))

          transaction_block_op_query =
            if UserOperation.enabled?() do
              user_operation_query = search_user_operation_query(full_hash)

              transaction_block_query
              |> union_all(^user_operation_query)
            else
              transaction_block_query
            end

          result_query =
            if Application.get_env(:explorer, :chain_type) == :ethereum do
              blob_query = search_blob_query(full_hash)

              transaction_block_op_query
              |> union_all(^blob_query)
            else
              transaction_block_op_query
            end

          result_query
          |> select_repo(options).all()

        {:number, block_number} ->
          block_number
          |> search_block_by_number_query()
          |> select_repo(options).all()

        [{:number, block_number}, {:text, prepared_term}] ->
          prepared_term
          |> search_by_string(paging_options)
          |> union_all(^search_block_by_number_query(block_number))
          |> order_and_page_text_search_result(paging_options)
          |> select_repo(options).all()

        {:text, prepared_term} ->
          prepared_term
          |> search_by_string(paging_options)
          |> order_and_page_text_search_result(paging_options)
          |> select_repo(options).all()
      end

    prepared_results =
      search_results
      |> Enum.map(fn result ->
        result
        |> compose_result_checksummed_address_hash()
        |> format_timestamp()
      end)

    ens_result = (ens_task && await_ens_task(ens_task)) || []

    trim_list_and_prepare_next_page_params(ens_result ++ prepared_results, paging_options, query_string)
  end

  defp order_and_page_text_search_result(query, paging_options) do
    query
    |> subquery()
    |> order_by([item],
      desc: item.priority,
      desc_nulls_last: item.certified,
      desc_nulls_last: item.circulating_market_cap,
      desc_nulls_last: item.exchange_rate,
      desc_nulls_last: item.is_verified_via_admin_panel,
      desc_nulls_last: item.holder_count,
      asc: item.name,
      desc: item.inserted_at
    )
    |> limit(^paging_options.page_size)
  end

  defp prepare_search_query(query, {:some, prepared_term}) do
    address_hash_result = Chain.string_to_address_hash(query)
    full_hash_result = Chain.string_to_transaction_hash(query)
    non_negative_integer_result = ExplorerHelper.safe_parse_non_negative_integer(query)
    query_length = String.length(query)

    cond do
      match?({:ok, _hash}, address_hash_result) ->
        {:ok, hash} = address_hash_result
        {:address_hash, hash}

      match?({:ok, _hash}, full_hash_result) ->
        {:ok, hash} = full_hash_result
        {:full_hash, hash}

      match?({:ok, _block_number}, non_negative_integer_result) and query_length < @min_query_length ->
        {:ok, block_number} = non_negative_integer_result
        {:number, block_number}

      match?({:ok, _block_number}, non_negative_integer_result) and query_length >= @min_query_length ->
        {:ok, block_number} = non_negative_integer_result
        [{:number, block_number}, {:text, prepared_term}]

      query_length >= @min_query_length ->
        {:text, prepared_term}

      true ->
        nil
    end
  end

  defp prepare_search_query(_query, _) do
    nil
  end

  defp search_by_string(term, paging_options) do
    tokens_query_certified =
      term
      |> search_token_query_certified(paging_options)
      |> ExplorerHelper.maybe_hide_scam_addresses(:contract_address_hash)

    tokens_query_not_certified =
      term
      |> search_token_query_not_certified(paging_options)
      |> ExplorerHelper.maybe_hide_scam_addresses(:contract_address_hash)

    contracts_query =
      term |> search_contract_query(paging_options) |> ExplorerHelper.maybe_hide_scam_addresses(:address_hash)

    labels_query = search_label_query(term, paging_options)

    from(
      tokens in subquery(tokens_query_certified),
      union_all: ^tokens_query_not_certified,
      union_all: ^contracts_query,
      union_all: ^labels_query
    )
  end

  defp run_ens_task_if_first_page(%PagingOptions{key: nil}, query_string, options) do
    Task.async(fn -> search_ens_name(query_string, options) end)
  end

  defp run_ens_task_if_first_page(_, _query_string, _options), do: nil

  @doc """
    Search function. Differences from joint_search/4:
      1. Returns all the found categories (amount of results up to `paging_options.page_size`).
          For example if was found 50 tokens, 50 smart-contracts, 50 labels, 1 address, 1 transaction and 2 blocks (impossible, just example) and page_size=50. Then function will return:
            [1 address, 1 transaction, 2 blocks, 16 tokens, 15 smart-contracts, 15 labels]
      2. Results couldn't be paginated

    `balanced_unpaginated_search` function is used at api/v2/search/quick endpoint.
  """
  @spec balanced_unpaginated_search(PagingOptions.t(), binary(), [Chain.api?()] | []) :: list
  def balanced_unpaginated_search(paging_options, query_string, options \\ []) do
    query_string = String.trim(query_string)
    ens_task = Task.async(fn -> search_ens_name(query_string, options) end)

    results =
      query_string
      |> prepare_search_query(prepare_search_term(query_string))
      |> case do
        nil ->
          []

        {:address_hash, address_hash} ->
          [
            address_hash
            |> search_token_by_address_hash_query()
            |> union_all(^search_address_by_address_hash_query(address_hash))
            |> select_repo(options).all()
          ]

        {:full_hash, full_hash} ->
          transaction_block_query =
            full_hash
            |> search_transaction_query()
            |> union_all(^search_block_by_hash_query(full_hash))

          transaction_block_op_query =
            if UserOperation.enabled?() do
              user_operation_query = search_user_operation_query(full_hash)

              transaction_block_query
              |> union_all(^user_operation_query)
            else
              transaction_block_query
            end

          result_query =
            if Application.get_env(:explorer, :chain_type) == :ethereum do
              blob_query = search_blob_query(full_hash)

              transaction_block_op_query
              |> union_all(^blob_query)
            else
              transaction_block_op_query
            end

          [
            result_query
            |> select_repo(options).all()
          ]

        {:number, block_number} ->
          [
            block_number
            |> search_block_by_number_query()
            |> select_repo(options).all()
          ]

        [{:number, block_number}, {:text, prepared_term}] ->
          [
            block_number |> search_block_by_number_query() |> select_repo(options).all()
            | search_by_string_balanced(prepared_term, paging_options, options)
          ]

        {:text, prepared_term} ->
          search_by_string_balanced(prepared_term, paging_options, options)
      end

    ens_result = await_ens_task(ens_task)

    non_empty_lists =
      [
        ens_result | results
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
  end

  defp search_by_string_balanced(term, paging_options, options) do
    tokens_results =
      (term
       |> search_token_query_certified(paging_options)
       |> ExplorerHelper.maybe_hide_scam_addresses(:contract_address_hash)
       |> select_repo(options).all()) ++
        (term
         |> search_token_query_not_certified(paging_options)
         |> ExplorerHelper.maybe_hide_scam_addresses(:contract_address_hash)
         |> select_repo(options).all())

    contracts_results =
      term
      |> search_contract_query(paging_options)
      |> ExplorerHelper.maybe_hide_scam_addresses(:address_hash)
      |> select_repo(options).all()

    labels_query = term |> search_label_query(paging_options) |> select_repo(options).all()

    [tokens_results, contracts_results, labels_query]
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

  defp search_label_query(term, paging_options) do
    label_search_fields =
      search_fields()
      |> Map.put(:address_hash, dynamic([address_to_tag: att], att.address_hash))
      |> Map.put(:type, "label")
      |> Map.put(:name, dynamic([address_tag: at], at.display_name))
      |> Map.put(:inserted_at, dynamic([address_to_tag: att], att.inserted_at))
      |> Map.put(:verified, dynamic([smart_contract: smart_contract], not is_nil(smart_contract)))
      |> Map.put(:priority, 1)

    inner_query =
      from(tag in AddressTag,
        where: fragment("to_tsvector('english', ?) @@ to_tsquery(?)", tag.display_name, ^term),
        select: tag
      )

    base_query =
      from(att in AddressToTag,
        as: :address_to_tag,
        inner_join: at in subquery(inner_query),
        as: :address_tag,
        on: att.tag_id == at.id,
        left_join: smart_contract in SmartContract,
        as: :smart_contract,
        on: att.address_hash == smart_contract.address_hash,
        select: ^label_search_fields
      )

    base_query
    |> apply_sorting([], @label_sorting)
    |> page_search_results(paging_options, "label")
  end

  defp search_token_query_not_certified(term, paging_options) do
    term
    |> search_token_by_symbol_or_name_query(paging_options)
    |> where([smart_contract: smart_contract], is_nil(smart_contract.certified) or not smart_contract.certified)
  end

  defp search_token_query_certified(term, paging_options) do
    term
    |> search_token_by_symbol_or_name_query(paging_options)
    |> where([smart_contract: smart_contract], smart_contract.certified)
  end

  defp search_token_by_symbol_or_name_query(term, paging_options) do
    base_query =
      from(token in Token,
        as: :token,
        left_join: smart_contract in SmartContract,
        as: :smart_contract,
        on: token.contract_address_hash == smart_contract.address_hash,
        where: fragment("to_tsvector('english', ? || ' ' || ?) @@ to_tsquery(?)", token.symbol, token.name, ^term),
        select: ^token_search_fields()
      )

    base_query |> apply_sorting([], @token_sorting) |> page_search_results(paging_options, "token")
  end

  defp search_token_by_address_hash_query(address_hash) do
    from(token in Token,
      as: :token,
      left_join: smart_contract in SmartContract,
      as: :smart_contract,
      on: token.contract_address_hash == smart_contract.address_hash,
      where: token.contract_address_hash == ^address_hash,
      select: ^token_search_fields()
    )
  end

  defp search_contract_query(term, paging_options) do
    contract_search_fields =
      search_fields()
      |> Map.put(:address_hash, dynamic([smart_contract: smart_contract], smart_contract.address_hash))
      |> Map.put(:type, "contract")
      |> Map.put(:name, dynamic([smart_contract: smart_contract], smart_contract.name))
      |> Map.put(:inserted_at, dynamic([smart_contract: smart_contract], smart_contract.inserted_at))
      |> Map.put(:certified, dynamic([smart_contract: smart_contract], smart_contract.certified))
      |> Map.put(:verified, true)

    base_query =
      from(smart_contract in SmartContract,
        as: :smart_contract,
        where: fragment("to_tsvector('english', ?) @@ to_tsquery(?)", smart_contract.name, ^term),
        select: ^contract_search_fields
      )

    base_query
    |> apply_sorting([], @contract_sorting)
    |> page_search_results(paging_options, "contract")
  end

  defp search_address_by_address_hash_query(address_hash) do
    address_search_fields =
      search_fields()
      |> Map.put(:address_hash, dynamic([address: address], address.hash))
      |> Map.put(:type, "address")
      |> Map.put(:name, dynamic([address_name: address_name], address_name.name))
      |> Map.put(:inserted_at, dynamic([address_name: address_name], address_name.inserted_at))
      |> Map.put(:verified, dynamic([address: address], address.verified))
      |> Map.put(:certified, dynamic([smart_contract: smart_contract], smart_contract.certified))

    from(address in Address,
      as: :address,
      left_join:
        address_name in subquery(
          from(name in Address.Name,
            where: name.address_hash == ^address_hash,
            order_by: [desc: name.primary],
            limit: 1
          )
        ),
      as: :address_name,
      on: address.hash == address_name.address_hash,
      left_join: smart_contract in SmartContract,
      as: :smart_contract,
      on: address.hash == smart_contract.address_hash,
      where: address.hash == ^address_hash,
      select: ^address_search_fields
    )
  end

  defp search_transaction_query(hash) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      transaction_search_fields =
        search_fields()
        |> Map.put(:transaction_hash, dynamic([transaction: transaction], transaction.hash))
        |> Map.put(:block_hash, dynamic([transaction: transaction], transaction.block_hash))
        |> Map.put(:type, "transaction")
        |> Map.put(:block_number, dynamic([transaction: transaction], transaction.block_number))
        |> Map.put(:inserted_at, dynamic([transaction: transaction], transaction.inserted_at))
        |> Map.put(:timestamp, dynamic([transaction: transaction], transaction.block_timestamp))

      from(transaction in Transaction,
        as: :transaction,
        where: transaction.hash == ^hash,
        select: ^transaction_search_fields
      )
    else
      transaction_search_fields =
        search_fields()
        |> Map.put(:transaction_hash, dynamic([transaction: transaction], transaction.hash))
        |> Map.put(:block_hash, dynamic([transaction: transaction], transaction.block_hash))
        |> Map.put(:type, "transaction")
        |> Map.put(:block_number, dynamic([transaction: transaction], transaction.block_number))
        |> Map.put(:inserted_at, dynamic([transaction: transaction], transaction.inserted_at))
        |> Map.put(:timestamp, dynamic([block: block], block.timestamp))

      from(transaction in Transaction,
        as: :transaction,
        left_join: block in Block,
        as: :block,
        on: transaction.block_hash == block.hash,
        where: transaction.hash == ^hash,
        select: ^transaction_search_fields
      )
    end
  end

  defp search_user_operation_query(term) do
    user_operation_search_fields =
      search_fields()
      |> Map.put(:user_operation_hash, dynamic([user_operation: user_operation], user_operation.hash))
      |> Map.put(:block_hash, dynamic([user_operation: user_operation], user_operation.block_hash))
      |> Map.put(:type, "user_operation")
      |> Map.put(:inserted_at, dynamic([user_operation: user_operation], user_operation.inserted_at))
      |> Map.put(:block_number, dynamic([user_operation: user_operation], user_operation.block_number))
      |> Map.put(:timestamp, dynamic([block: block], block.timestamp))

    from(user_operation in UserOperation,
      as: :user_operation,
      left_join: block in Block,
      as: :block,
      on: user_operation.block_hash == block.hash,
      where: user_operation.hash == ^term,
      select: ^user_operation_search_fields
    )
  end

  defp search_blob_query(term) do
    blob_search_fields =
      search_fields()
      |> Map.put(:blob_hash, dynamic([blob: blob], blob.hash))
      |> Map.put(:type, "blob")
      |> Map.put(:inserted_at, dynamic([blob: blob], blob.inserted_at))

    from(blob in Blob,
      as: :blob,
      where: blob.hash == ^term,
      select: ^blob_search_fields
    )
  end

  defp search_block_by_hash_query(hash) do
    search_block_base_query()
    |> where([block: block], block.hash == ^hash)
  end

  defp search_block_by_number_query(number) do
    search_block_base_query()
    |> where([block: block], block.number == ^number)
  end

  defp search_block_base_query do
    block_search_fields =
      search_fields()
      |> Map.put(:block_hash, dynamic([block: block], block.hash))
      |> Map.put(:type, "block")
      |> Map.put(:block_number, dynamic([block: block], block.number))
      |> Map.put(:inserted_at, dynamic([block: block], block.inserted_at))
      |> Map.put(:timestamp, dynamic([block: block], block.timestamp))

    from(block in Block,
      as: :block,
      select: ^block_search_fields
    )
  end

  defp page_search_results(
         query,
         %PagingOptions{
           key: %{
             "label" => %{
               "name" => name,
               "inserted_at" => inserted_at
             }
           },
           page_size: page_size
         },
         "label"
       ) do
    query
    |> page_with_sorting(
      %PagingOptions{
        key: %{
          display_name: name,
          inserted_at: inserted_at
        },
        page_size: page_size
      },
      [],
      [{:asc, :display_name, :address_tag}, {:desc, :inserted_at, :address_to_tag}]
    )
  end

  defp page_search_results(
         query,
         %PagingOptions{
           key: %{
             "contract" => %{
               "certified" => certified,
               "name" => name,
               "inserted_at" => inserted_at
             }
           },
           page_size: page_size
         },
         "contract"
       ) do
    query
    |> page_with_sorting(
      %PagingOptions{
        key: %{
          certified: parse_possible_nil(certified),
          name: parse_possible_nil(name),
          inserted_at: inserted_at
        },
        page_size: page_size
      },
      [],
      [
        {:desc_nulls_last, :certified, :smart_contract},
        {:asc, :name, :smart_contract},
        {:desc, :inserted_at, :smart_contract}
      ]
    )
  end

  defp page_search_results(
         query,
         %PagingOptions{
           key: %{
             "token" => %{
               "circulating_market_cap" => circulating_market_cap,
               "fiat_value" => fiat_value,
               "is_verified_via_admin_panel" => is_verified_via_admin_panel,
               "holder_count" => holder_count,
               "name" => name,
               "inserted_at" => inserted_at
             }
           },
           page_size: page_size
         },
         "token"
       ) do
    query
    |> page_with_sorting(
      %PagingOptions{
        key: %{
          circulating_market_cap: parse_possible_nil(circulating_market_cap),
          fiat_value: parse_possible_nil(fiat_value),
          is_verified_via_admin_panel: parse_possible_nil(is_verified_via_admin_panel),
          holder_count: parse_possible_nil(holder_count),
          name: name,
          inserted_at: inserted_at
        },
        page_size: page_size
      },
      [],
      [
        {:desc_nulls_last, :circulating_market_cap, :token},
        {:desc_nulls_last, :fiat_value, :token},
        {:desc_nulls_last, :is_verified_via_admin_panel, :token},
        {:desc_nulls_last, :holder_count, :token},
        {:asc, :name, :token},
        {:desc, :inserted_at, :token}
      ]
    )
  end

  defp page_search_results(query, %PagingOptions{page_size: page_size}, _query_type),
    do: limit(query, ^page_size)

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

  # For some reasons timestamp for blocks and transactions returns as ~N[2023-06-25 19:39:47.339493]
  defp format_timestamp(result) do
    if result.timestamp do
      result
      |> Map.put(:timestamp, DateTime.from_naive!(result.timestamp, "Etc/UTC"))
    else
      result
    end
  end

  defp search_ens_name(search_query, options) do
    case search_ens_name_in_bens(search_query) do
      {ens_result, address_hash} ->
        [
          address_hash
          |> search_address_by_address_hash_query()
          |> ExplorerHelper.maybe_hide_scam_addresses(:hash)
          |> select_repo(options).all()
          |> merge_address_search_result_with_ens_info(ens_result)
        ]

      _ ->
        []
    end
  end

  @doc """
  Try to resolve ENS domain via BENS
  """
  @spec search_ens_name_in_bens(binary()) ::
          nil
          | {%{
               address_hash: binary(),
               expiry_date: any(),
               name: any(),
               names_count: non_neg_integer(),
               protocol: any()
             }, Hash.Address.t()}
  def search_ens_name_in_bens(search_query) do
    trimmed_query = String.trim(search_query)

    with true <- Regex.match?(~r/\w+\.\w+/, trimmed_query),
         %{address_hash: address_hash_string} = result <- ens_domain_name_lookup(search_query),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      {result, address_hash}
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
      address_hash: dynamic(type(^nil, :binary)),
      transaction_hash: dynamic(type(^nil, :binary)),
      user_operation_hash: dynamic(type(^nil, :binary)),
      blob_hash: dynamic(type(^nil, :binary)),
      block_hash: dynamic(type(^nil, :binary)),
      type: nil,
      name: nil,
      symbol: nil,
      holder_count: nil,
      inserted_at: nil,
      block_number: 0,
      icon_url: nil,
      token_type: nil,
      timestamp: dynamic(type(^nil, :utc_datetime_usec)),
      verified: nil,
      certified: nil,
      exchange_rate: nil,
      total_supply: nil,
      circulating_market_cap: nil,
      priority: 0,
      is_verified_via_admin_panel: nil
    }
  end

  defp token_search_fields do
    search_fields()
    |> Map.put(:address_hash, dynamic([token: token], token.contract_address_hash))
    |> Map.put(:type, "token")
    |> Map.put(:name, dynamic([token: token], token.name))
    |> Map.put(:symbol, dynamic([token: token], token.symbol))
    |> Map.put(:holder_count, dynamic([token: token], token.holder_count))
    |> Map.put(:inserted_at, dynamic([token: token], token.inserted_at))
    |> Map.put(:icon_url, dynamic([token: token], token.icon_url))
    |> Map.put(:token_type, dynamic([token: token], token.type))
    |> Map.put(:exchange_rate, dynamic([token: token], token.fiat_value))
    |> Map.put(:total_supply, dynamic([token: token], token.total_supply))
    |> Map.put(:circulating_market_cap, dynamic([token: token], token.circulating_market_cap))
    |> Map.put(:is_verified_via_admin_panel, dynamic([token: token], token.is_verified_via_admin_panel))
    |> Map.put(:verified, dynamic([smart_contract: smart_contract], not is_nil(smart_contract)))
    |> Map.put(:certified, dynamic([smart_contract: smart_contract], smart_contract.certified))
  end

  @paginated_types ["label", "contract", "token"]

  defp trim_list_and_prepare_next_page_params(items, %PagingOptions{page_size: page_size, key: prev_options}, query)
       when length(items) > page_size - 1 do
    items = items |> Enum.drop(-1)
    prev_options = prev_options || %{}

    base_params =
      Map.merge(
        %{"next_page_params_type" => "search", "q" => query},
        prev_options
      )

    {paging_options, _types} =
      items
      |> Enum.reverse()
      |> Enum.reduce_while({base_params, @paginated_types}, fn
        _item, {_paging_options, []} = acc ->
          {:halt, acc}

        item, {paging_options, types} = acc ->
          if item.type in types do
            {:cont, {Map.put(paging_options, item.type, paging_params(item)), List.delete(types, item.type)}}
          else
            {:cont, acc}
          end
      end)

    {items, paging_options}
  end

  defp trim_list_and_prepare_next_page_params(items, _paging_options, _query), do: {items, nil}

  defp paging_params(%{
         name: name,
         inserted_at: inserted_at,
         type: "label"
       }) do
    inserted_at_datetime = DateTime.to_iso8601(inserted_at)

    %{
      "name" => name,
      "inserted_at" => inserted_at_datetime
    }
  end

  defp paging_params(%{
         circulating_market_cap: circulating_market_cap,
         exchange_rate: exchange_rate,
         is_verified_via_admin_panel: is_verified_via_admin_panel,
         holder_count: holder_count,
         name: name,
         inserted_at: inserted_at,
         type: "token"
       }) do
    inserted_at_datetime = DateTime.to_iso8601(inserted_at)

    %{
      "circulating_market_cap" => circulating_market_cap,
      "fiat_value" => exchange_rate,
      "is_verified_via_admin_panel" => is_verified_via_admin_panel,
      "holder_count" => holder_count,
      "name" => name,
      "inserted_at" => inserted_at_datetime
    }
  end

  defp paging_params(%{
         certified: certified,
         name: name,
         inserted_at: inserted_at,
         type: "contract"
       }) do
    inserted_at_datetime = DateTime.to_iso8601(inserted_at)

    %{
      "certified" => certified,
      "name" => name,
      "inserted_at" => inserted_at_datetime
    }
  end

  @doc """
  Parses paging options from the given parameters when the `next_page_params_type` is "search".

  ## Parameters

    - paging_params: A map containing the paging parameters, including "next_page_params_type".

  ## Returns

  A keyword list with paging options, where key is the map with the parsed paging options.
  """
  @spec parse_paging_options(map()) :: [paging_options: PagingOptions.t()]
  def parse_paging_options(%{"next_page_params_type" => "search"} = paging_params) do
    key =
      Enum.reduce(@paginated_types, %{}, fn type, acc ->
        if Map.has_key?(paging_params, type) do
          Map.put(acc, type, paging_options(paging_params[type]))
        else
          acc
        end
      end)

    [paging_options: %{default_paging_options() | key: key}]
  end

  def parse_paging_options(_) do
    [paging_options: default_paging_options()]
  end

  defp paging_options(paging_options) when is_map(paging_options) do
    paging_options
  end

  defp paging_options(_), do: nil

  defp parse_possible_nil(""), do: nil
  defp parse_possible_nil("null"), do: nil
  defp parse_possible_nil(other), do: other
end
