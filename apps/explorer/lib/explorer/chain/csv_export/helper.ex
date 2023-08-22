defmodule Explorer.Chain.CSVExport.Helper do
  @moduledoc """
  CSV export helper functions.
  """

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Hash.Full, as: Hash
  alias NimbleCSV.RFC4180

  import Ecto.Query,
    only: [
      where: 3
    ]

  @limit 10_000
  @page_size 150
  @default_paging_options %PagingOptions{page_size: @page_size}

  def dump_to_stream(items) do
    items
    |> RFC4180.dump_to_stream()
  end

  def page_size, do: @page_size

  def default_paging_options, do: @default_paging_options

  def limit, do: @limit

  def block_from_period(from_period, to_period) do
    from_block = Chain.convert_date_to_min_block(from_period)
    to_block = Chain.convert_date_to_max_block(to_period)

    {from_block, to_block}
  end

  def where_address_hash(query, address_hash, filter_type, filter_value) do
    if filter_type == "address" do
      case filter_value do
        "to" -> where_address_hash_to(query, address_hash)
        "from" -> where_address_hash_from(query, address_hash)
        _ -> where_address_hash_all(query, address_hash)
      end
    else
      where_address_hash_all(query, address_hash)
    end
  end

  defp where_address_hash_to(query, address_hash) do
    query
    |> where(
      [item],
      item.to_address_hash == ^address_hash
    )
  end

  defp where_address_hash_from(query, address_hash) do
    query
    |> where(
      [item],
      item.from_address_hash == ^address_hash
    )
  end

  defp where_address_hash_all(query, address_hash) do
    query
    |> where(
      [item],
      item.to_address_hash == ^address_hash or
        item.from_address_hash == ^address_hash or
        item.token_contract_address_hash == ^address_hash
    )
  end

  @spec supported_filters(String.t()) :: [String.t()]
  def supported_filters(type) do
    case type do
      "internal-transactions" -> ["address"]
      "transactions" -> ["address"]
      "token-transfers" -> ["address"]
      "logs" -> ["topic"]
      _ -> []
    end
  end

  @spec supported_address_filter_values() :: [String.t()]
  def supported_address_filter_values do
    ["to", "from"]
  end

  @spec is_valid_filter?(String.t(), String.t(), String.t()) :: boolean()
  def is_valid_filter?(filter_type, filter_value, item_type) do
    is_valid_filter_type(filter_type, filter_value, item_type) && is_valid_filter_value(filter_type, filter_value)
  end

  defp is_valid_filter_type(filter_type, filter_value, item_type) do
    filter_type in supported_filters(item_type) && filter_value && filter_value !== ""
  end

  defp is_valid_filter_value(filter_type, filter_value) do
    case filter_type do
      "address" ->
        filter_value in supported_address_filter_values()

      "topic" ->
        case Hash.cast(filter_value) do
          {:ok, _} -> true
          _ -> false
        end

      _ ->
        true
    end
  end
end
