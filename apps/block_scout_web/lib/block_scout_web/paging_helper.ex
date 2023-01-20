defmodule BlockScoutWeb.PagingHelper do
  @moduledoc """
    Helper for fetching filters and other url query paramters
  """
  import Explorer.Chain, only: [string_to_transaction_hash: 1]
  alias Explorer.PagingOptions

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}
  @allowed_filter_labels ["validated", "pending"]
  @allowed_type_labels ["coin_transfer", "contract_call", "contract_creation", "token_transfer", "token_creation"]
  @allowed_token_transfer_type_labels ["ERC-20", "ERC-721", "ERC-1155"]

  def paging_options(%{"block_number" => block_number_string, "index" => index_string}, [:validated | _]) do
    with {block_number, ""} <- Integer.parse(block_number_string),
         {index, ""} <- Integer.parse(index_string) do
      [paging_options: %{@default_paging_options | key: {block_number, index}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"inserted_at" => inserted_at_string, "hash" => hash_string}, [:pending | _]) do
    with {:ok, inserted_at, _} <- DateTime.from_iso8601(inserted_at_string),
         {:ok, hash} <- string_to_transaction_hash(hash_string) do
      [paging_options: %{@default_paging_options | key: {inserted_at, hash}, is_pending_tx: true}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(_params, _filter), do: [paging_options: @default_paging_options]

  def token_transfers_types_options(%{"type" => filters}) do
    [
      token_type: filters |> String.upcase() |> parse_filter(@allowed_token_transfer_type_labels)
    ]
  end

  def token_transfers_types_options(_), do: [token_type: []]

  # sobelow_skip ["DOS.StringToAtom"]
  def filter_options(%{"filter" => filter}, fallback) do
    filter = filter |> parse_filter(@allowed_filter_labels) |> Enum.map(&String.to_atom/1)
    if(filter == [], do: [fallback], else: filter)
  end

  def filter_options(_params, fallback), do: [fallback]

  # sobelow_skip ["DOS.StringToAtom"]
  def type_filter_options(%{"type" => type}) do
    [type: type |> parse_filter(@allowed_type_labels) |> Enum.map(&String.to_atom/1)]
  end

  def type_filter_options(_params), do: [type: []]

  def method_filter_options(%{"method" => method}) do
    [method: parse_method_filter(method)]
  end

  def method_filter_options(_params), do: [method: []]

  def parse_filter("[" <> filter, allowed_labels) do
    filter
    |> String.trim_trailing("]")
    |> parse_filter(allowed_labels)
  end

  def parse_filter(filter, allowed_labels) when is_binary(filter) do
    filter
    |> String.split(",")
    |> Enum.filter(fn label -> Enum.member?(allowed_labels, label) end)
    |> Enum.uniq()
  end

  def parse_method_filter("[" <> filter) do
    filter
    |> String.trim_trailing("]")
    |> parse_method_filter()
  end

  def parse_method_filter(filter) do
    filter
    |> String.split(",")
    |> Enum.uniq()
  end

  def select_block_type(%{"type" => type}) do
    case String.downcase(type) do
      "uncle" ->
        [
          necessity_by_association: %{
            :transactions => :optional,
            [miner: :names] => :optional,
            :nephews => :required,
            :rewards => :optional
          },
          block_type: "Uncle"
        ]

      "reorg" ->
        [
          necessity_by_association: %{
            :transactions => :optional,
            [miner: :names] => :optional,
            :rewards => :optional
          },
          block_type: "Reorg"
        ]

      _ ->
        select_block_type(nil)
    end
  end

  def select_block_type(_),
    do: [
      necessity_by_association: %{
        :transactions => :optional,
        [miner: :names] => :optional,
        :rewards => :optional
      },
      block_type: "Block"
    ]

  def delete_parameters_from_next_page_params(params) when is_map(params) do
    params
    |> Map.delete("block_hash_or_number")
    |> Map.delete("transaction_hash")
    |> Map.delete("address_hash")
    |> Map.delete("type")
    |> Map.delete("method")
    |> Map.delete("filter")
    |> Map.delete("token_address_hash")
  end

  def delete_parameters_from_next_page_params(_), do: nil
end
