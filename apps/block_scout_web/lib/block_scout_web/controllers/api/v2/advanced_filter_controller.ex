defmodule BlockScoutWeb.API.V2.AdvancedFilterController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [default_paging_options: 0, split_list_by_page: 1, next_page_params: 4]

  alias Explorer.Chain
  alias Explorer.Chain.AdvancedFilter

  def list(conn, params) do
    full_options = params |> extract_filters() |> Keyword.merge(paging_options(params))

    advanced_filters_plus_one = AdvancedFilter.list(full_options)

    {advanced_filters, next_page} = split_list_by_page(advanced_filters_plus_one)

    next_page_params =
      next_page |> next_page_params(advanced_filters, Map.take(params, ["items_count"]), &paging_params/1)

    render(conn, :advanced_filters, advanced_filters: advanced_filters, next_page_params: next_page_params)
  end

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

  def list_methods(conn, _params) do
    render(conn, :methods, methods: @methods)
  end

  defp extract_filters(params) do
    [
      tx_types: prepare_tx_types(params["tx_types"]),
      methods: prepare_methods(params["methods"]),
      age: prepare_age(params["age_from"], params["age_to"]),
      from_address_hashes: prepare_address_hashes(params["from_address_hashes"]),
      to_address_hashes: prepare_address_hashes(params["to_address_hashes"]),
      address_relation: prepare_address_relation(params["address_relation"]),
      amount: prepare_amount(params["amount_from"], params["amount_to"]),
      token_contract_address_hashes:
        prepare_token_contract_address_hashes(
          params["token_contract_address_hashes_to_include"],
          params["token_contract_address_hashes_to_exclude"]
        )
    ]
  end

  @allowed_tx_types ~w(coin_transfer ERC-20 ERC-404 ERC-721 ERC-1155)

  defp prepare_tx_types(tx_types) when not is_nil(tx_types) do
    tx_types
    |> String.split(",")
    |> Enum.filter(&(&1 in @allowed_tx_types))
  end

  defp prepare_tx_types(_), do: nil

  defp prepare_methods(methods) when not is_nil(methods) do
    methods
    |> String.split(",")
    |> Enum.filter(fn prefixed_method_id ->
      case prefixed_method_id do
        "0x" <> method_id when byte_size(method_id) == 8 -> true
        _ -> false
      end
    end)
  end

  defp prepare_methods(_), do: nil

  defp prepare_age(from, to), do: [from: parse_date(from), to: parse_date(to)]

  defp parse_date(string_date) do
    case string_date && DateTime.from_iso8601(string_date) do
      {:ok, date, utc_offset} -> Timex.shift(date, seconds: utc_offset)
      _ -> nil
    end
  end

  defp prepare_address_hashes(from) when not is_nil(from) do
    from
    |> String.split(",")
    |> Enum.flat_map(fn maybe_address_hash ->
      case Chain.string_to_address_hash(maybe_address_hash) do
        {:ok, address_hash} -> [address_hash]
        _ -> []
      end
    end)
  end

  defp prepare_address_hashes(_), do: nil

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

  defp prepare_token_contract_address_hashes(include, exclude) when not is_nil(include) or not is_nil(exclude) do
    [include: prepare_address_hashes(include), exclude: prepare_address_hashes(exclude)]
  end

  defp prepare_token_contract_address_hashes(_, _), do: nil

  # Paging

  defp paging_options(%{
         "block_number" => block_number_string,
         "transaction_index" => tx_index_string,
         "internal_transaction_index" => internal_tx_index_string,
         "token_transfer_index" => token_transfer_index_string
       }) do
    with {block_number, ""} <- block_number_string && Integer.parse(block_number_string),
         {tx_index, ""} <- tx_index_string && Integer.parse(tx_index_string),
         {:ok, internal_tx_index} <- parse_nullable_integer_paging_parameter(internal_tx_index_string),
         {:ok, token_transfer_index} <- parse_nullable_integer_paging_parameter(token_transfer_index_string) do
      [
        paging_options: %{
          default_paging_options()
          | key: %{
              block_number: block_number,
              transaction_index: tx_index,
              internal_transaction_index: internal_tx_index,
              token_transfer_index: token_transfer_index
            }
        }
      ]
    else
      _ -> [paging_options: default_paging_options()]
    end
  end

  defp paging_options(_), do: [paging_options: default_paging_options()]

  defp parse_nullable_integer_paging_parameter(""), do: {:ok, nil}

  defp parse_nullable_integer_paging_parameter(string) when is_binary(string) do
    case Integer.parse(string) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, :invalid_paging_parameter}
    end
  end

  defp parse_nullable_integer_paging_parameter(_), do: {:error, :invalid_paging_parameter}

  defp paging_params(%AdvancedFilter{
         block_number: block_number,
         transaction_index: tx_index,
         internal_transaction_index: internal_tx_index,
         token_transfer_index: token_transfer_index
       }) do
    %{
      block_number: block_number,
      transaction_index: tx_index,
      internal_transaction_index: internal_tx_index,
      token_transfer_index: token_transfer_index
    }
  end
end
