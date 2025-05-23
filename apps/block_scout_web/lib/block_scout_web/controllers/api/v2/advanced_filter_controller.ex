defmodule BlockScoutWeb.API.V2.AdvancedFilterController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [split_list_by_page: 1, next_page_params: 4, fetch_scam_token_toggle: 2]
  import Explorer.PagingOptions, only: [default_paging_options: 0]

  alias BlockScoutWeb.API.V2.{AdvancedFilterView, CsvExportController}
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{AdvancedFilter, ContractMethod, Data, Token, Transaction}
  alias Explorer.Chain.CsvExport.Helper, as: CsvHelper
  alias Explorer.Helper, as: ExplorerHelper
  alias Plug.Conn

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @api_true [api?: true]

  @methods [
    %{method_id: "0xa9059cbb", name: "transfer"},
    %{method_id: "0xa0712d68", name: "mint"},
    %{method_id: "0x095ea7b3", name: "approve"},
    %{method_id: "0x40993b26", name: "buy"},
    %{method_id: "0x3593564c", name: "execute"},
    %{method_id: "0x3ccfd60b", name: "withdraw"},
    %{method_id: "0xd0e30db0", name: "deposit"},
    %{method_id: "0x0a19b14a", name: "trade"},
    %{method_id: "0x4420e486", name: "register"},
    %{method_id: "0x5f575529", name: "swap"},
    %{method_id: "0xd9627aa4", name: "sellToUniswap"},
    %{method_id: "0xe9e05c42", name: "depositTransaction"},
    %{method_id: "0x23b872dd", name: "transferFrom"},
    %{method_id: "0xa22cb465", name: "setApprovalForAll"},
    %{method_id: "0x2e7ba6ef", name: "claim"},
    %{method_id: "0x0502b1c5", name: "unoswap"},
    %{method_id: "0xb2267a7b", name: "sendMessage"},
    %{method_id: "0x9871efa4", name: "unxswapByOrderId"},
    %{method_id: "0xbf6eac2f", name: "stake"},
    %{method_id: "0x3ce33bff", name: "bridge"},
    %{method_id: "0xeb672419", name: "requestL2Transaction"},
    %{method_id: "0xe449022e", name: "uniswapV3Swap"},
    %{method_id: "0x0162e2d0", name: "swapETHForExactTokens"}
  ]

  @methods_id_to_name_map Map.new(@methods, fn %{method_id: method_id, name: name} -> {method_id, name} end)
  @methods_name_to_id_map Map.new(@methods, fn %{method_id: method_id, name: name} -> {name, method_id} end)

  @methods_filter_limit 20
  @tokens_filter_limit 20

  @doc """
  Function responsible for `api/v2/advanced-filters/` endpoint.
  """
  @spec list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list(conn, params) do
    full_options =
      params
      |> extract_filters()
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(@api_true)
      |> fetch_scam_token_toggle(conn)

    advanced_filters_plus_one = AdvancedFilter.list(full_options)

    {advanced_filters, next_page} = split_list_by_page(advanced_filters_plus_one)

    decoded_transactions =
      advanced_filters
      |> Enum.map(fn af -> %Transaction{to_address: af.to_address, input: af.input, hash: af.hash} end)
      |> Transaction.decode_transactions(true, @api_true)

    next_page_params =
      next_page |> next_page_params(advanced_filters, Map.take(params, ["items_count"]), &paging_params/1)

    render(conn, :advanced_filters,
      advanced_filters: advanced_filters,
      decoded_transactions: decoded_transactions,
      search_params: %{
        method_ids: method_id_to_name_from_params(full_options[:methods] || [], decoded_transactions),
        tokens: contract_address_hash_to_token_from_params(full_options[:token_contract_address_hashes])
      },
      next_page_params: next_page_params
    )
  end

  @doc """
  Function responsible for `api/v2/advanced-filters/csv` endpoint.
  """
  @spec list_csv(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_csv(conn, params) do
    full_options =
      params
      |> extract_filters()
      |> Keyword.merge(paging_options(params))
      |> Keyword.update(:paging_options, %PagingOptions{page_size: CsvHelper.limit()}, fn paging_options ->
        %PagingOptions{paging_options | page_size: CsvHelper.limit()}
      end)
      |> Keyword.put(:timeout, :timer.minutes(5))

    full_options
    |> AdvancedFilter.list()
    |> AdvancedFilterView.to_csv_format()
    |> CsvHelper.dump_to_stream()
    |> Enum.reduce_while(CsvExportController.put_resp_params(conn), fn chunk, conn ->
      case Conn.chunk(conn, chunk) do
        {:ok, conn} ->
          {:cont, conn}

        {:error, :closed} ->
          {:halt, conn}
      end
    end)
  end

  @doc """
  Function responsible for `api/v2/advanced-filters/methods` endpoint,
  including `api/v2/advanced-filters/methods/?q=:search_string`.
  """
  @spec list_methods(Plug.Conn.t(), map()) :: {:method, nil | Explorer.Chain.ContractMethod.t()} | Plug.Conn.t()
  def list_methods(conn, %{"q" => query}) do
    case {@methods_id_to_name_map[query], @methods_name_to_id_map[query]} do
      {name, _} when is_binary(name) ->
        render(conn, :methods, methods: [%{method_id: query, name: name}])

      {_, id} when is_binary(id) ->
        render(conn, :methods, methods: [%{method_id: id, name: query}])

      _ ->
        mb_contract_method =
          case Data.cast(query) do
            {:ok, %Data{bytes: <<_::bytes-size(4)>> = binary_method_id}} ->
              ContractMethod.find_contract_method_by_selector_id(binary_method_id, @api_true)

            _ ->
              ContractMethod.find_contract_method_by_name(query, @api_true)
          end

        case mb_contract_method do
          %ContractMethod{abi: %{"name" => name}, identifier: identifier} ->
            render(conn, :methods, methods: [%{method_id: ExplorerHelper.add_0x_prefix(identifier), name: name}])

          _ ->
            render(conn, :methods, methods: [])
        end
    end
  end

  def list_methods(conn, _params) do
    render(conn, :methods, methods: @methods)
  end

  defp method_id_to_name_from_params(prepared_method_ids, decoded_transactions) do
    {decoded_method_ids, method_ids_to_find} =
      Enum.reduce(prepared_method_ids, {%{}, []}, fn method_id, {decoded, to_decode} ->
        {:ok, method_id_hash} = Data.cast(method_id)
        trimmed_method_id = method_id_hash.bytes |> Base.encode16(case: :lower)

        case {Map.get(@methods_id_to_name_map, method_id),
              decoded_transactions |> Enum.find(&match?({:ok, ^trimmed_method_id, _, _}, &1))} do
          {name, _} when is_binary(name) ->
            {Map.put(decoded, method_id, name), to_decode}

          {_, {:ok, _, function_signature, _}} when is_binary(function_signature) ->
            {Map.put(decoded, method_id, function_signature |> String.split("(") |> Enum.at(0)), to_decode}

          {nil, nil} ->
            {decoded, [method_id_hash.bytes | to_decode]}
        end
      end)

    method_ids_to_find
    |> ContractMethod.find_contract_methods(@api_true)
    |> Enum.reduce(%{}, fn contract_method, acc ->
      case contract_method do
        %ContractMethod{abi: %{"name" => name}, identifier: identifier} when is_binary(name) ->
          Map.put(acc, ExplorerHelper.add_0x_prefix(identifier), name)

        _ ->
          acc
      end
    end)
    |> Map.merge(decoded_method_ids)
  end

  defp contract_address_hash_to_token_from_params(tokens) do
    token_contract_address_hashes_to_include = tokens[:include] || []

    token_contract_address_hashes_to_exclude = tokens[:exclude] || []

    token_contract_address_hashes_to_include
    |> Kernel.++(token_contract_address_hashes_to_exclude)
    |> Enum.reject(&(&1 == "native"))
    |> Enum.uniq()
    |> Enum.take(@tokens_filter_limit)
    |> Token.get_by_contract_address_hashes(@api_true)
    |> Map.new(fn token -> {token.contract_address_hash, token} end)
  end

  defp extract_filters(params) do
    [
      transaction_types: prepare_transaction_types(params["transaction_types"]),
      methods: params["methods"] |> prepare_methods(),
      age: prepare_age(params["age_from"], params["age_to"]),
      from_address_hashes:
        prepare_include_exclude_address_hashes(
          params["from_address_hashes_to_include"],
          params["from_address_hashes_to_exclude"],
          &prepare_address_hash/1
        ),
      to_address_hashes:
        prepare_include_exclude_address_hashes(
          params["to_address_hashes_to_include"],
          params["to_address_hashes_to_exclude"],
          &prepare_address_hash/1
        ),
      address_relation: prepare_address_relation(params["address_relation"]),
      amount: prepare_amount(params["amount_from"], params["amount_to"]),
      token_contract_address_hashes:
        params["token_contract_address_hashes_to_include"]
        |> prepare_include_exclude_address_hashes(
          params["token_contract_address_hashes_to_exclude"],
          &prepare_token_address_hash/1
        )
        |> Enum.map(fn
          {key, value} when is_list(value) -> {key, Enum.take(value, @tokens_filter_limit)}
          key_value -> key_value
        end)
    ]
  end

  @allowed_transaction_types ~w(COIN_TRANSFER ERC-20 ERC-404 ERC-721 ERC-1155)

  defp prepare_transaction_types(transaction_types) when is_binary(transaction_types) do
    transaction_types
    |> String.upcase()
    |> String.split(",")
    |> Enum.filter(&(&1 in @allowed_transaction_types))
  end

  defp prepare_transaction_types(_), do: nil

  defp prepare_methods(methods) when is_binary(methods) do
    methods
    |> String.downcase()
    |> String.split(",")
    |> Enum.filter(fn
      "0x" <> method_id when byte_size(method_id) == 8 ->
        case Base.decode16(method_id, case: :mixed) do
          {:ok, _} -> true
          _ -> false
        end

      _ ->
        false
    end)
    |> Enum.uniq()
    |> Enum.take(@methods_filter_limit)
  end

  defp prepare_methods(_), do: nil

  defp prepare_age(from, to), do: [from: parse_date(from), to: parse_date(to)]

  defp parse_date(string_date) do
    case string_date && DateTime.from_iso8601(string_date) do
      {:ok, date, _utc_offset} -> date
      _ -> nil
    end
  end

  defp prepare_address_hashes(address_hashes, map_filter_function)
       when is_binary(address_hashes) do
    address_hashes
    |> String.split(",")
    |> Enum.flat_map(&map_filter_function.(&1))
  end

  defp prepare_address_hashes(_, _), do: nil

  defp prepare_address_hash(maybe_address_hash) do
    case Chain.string_to_address_hash(maybe_address_hash) do
      {:ok, address_hash} -> [address_hash]
      _ -> []
    end
  end

  defp prepare_token_address_hash(token_address_hash) do
    case String.downcase(token_address_hash) do
      "native" -> ["native"]
      _ -> prepare_address_hash(token_address_hash)
    end
  end

  defp prepare_address_relation(relation) do
    case relation && String.downcase(relation) do
      r when r in [nil, "or"] -> :or
      "and" -> :and
      _ -> nil
    end
  end

  defp prepare_amount(from, to), do: [from: parse_decimal(from), to: parse_decimal(to)]

  defp parse_decimal(string_decimal) do
    case string_decimal && Decimal.parse(string_decimal) do
      {decimal, ""} -> decimal
      _ -> nil
    end
  end

  defp prepare_include_exclude_address_hashes(include, exclude, map_filter_function) do
    [
      include: prepare_address_hashes(include, map_filter_function),
      exclude: prepare_address_hashes(exclude, map_filter_function)
    ]
  end

  # Paging

  defp paging_options(%{
         "block_number" => block_number_string,
         "transaction_index" => transaction_index_string,
         "internal_transaction_index" => internal_transaction_index_string,
         "token_transfer_index" => token_transfer_index_string,
         "token_transfer_batch_index" => token_transfer_batch_index_string
       }) do
    with {block_number, ""} <- block_number_string && Integer.parse(block_number_string),
         {transaction_index, ""} <- transaction_index_string && Integer.parse(transaction_index_string),
         {:ok, internal_transaction_index} <-
           parse_nullable_integer_paging_parameter(internal_transaction_index_string),
         {:ok, token_transfer_index} <- parse_nullable_integer_paging_parameter(token_transfer_index_string),
         {:ok, token_transfer_batch_index} <- parse_nullable_integer_paging_parameter(token_transfer_batch_index_string) do
      [
        paging_options: %{
          default_paging_options()
          | key: %{
              block_number: block_number,
              transaction_index: transaction_index,
              internal_transaction_index: internal_transaction_index,
              token_transfer_index: token_transfer_index,
              token_transfer_batch_index: token_transfer_batch_index
            }
        }
      ]
    else
      _ -> [paging_options: default_paging_options()]
    end
  end

  defp paging_options(_), do: [paging_options: default_paging_options()]

  defp parse_nullable_integer_paging_parameter(""), do: {:ok, nil}
  defp parse_nullable_integer_paging_parameter("null"), do: {:ok, nil}

  defp parse_nullable_integer_paging_parameter(string) when is_binary(string) do
    case Integer.parse(string) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, :invalid_paging_parameter}
    end
  end

  defp parse_nullable_integer_paging_parameter(_), do: {:error, :invalid_paging_parameter}

  defp paging_params(%AdvancedFilter{
         block_number: block_number,
         transaction_index: transaction_index,
         internal_transaction_index: internal_transaction_index,
         token_transfer_index: token_transfer_index,
         token_transfer_batch_index: token_transfer_batch_index
       }) do
    %{
      block_number: block_number,
      transaction_index: transaction_index,
      internal_transaction_index: internal_transaction_index,
      token_transfer_index: token_transfer_index,
      token_transfer_batch_index: token_transfer_batch_index
    }
  end
end
