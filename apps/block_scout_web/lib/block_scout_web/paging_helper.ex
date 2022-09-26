defmodule BlockScoutWeb.PagingHelper do
  @moduledoc """
    Helper for fetching filters and other url query paramters
  """
  import Explorer.Chain, only: [string_to_transaction_hash: 1]
  alias Explorer.PagingOptions

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}
  @allowed_filter_labels ["validated", "pending"]
  @allowed_type_labels ["transaction", "contract_call", "contract_creation", "token_transfer", "token_creation"]

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

  def filter_options(%{"filter" => filter}) do
    parse_filter(filter, @allowed_filter_labels)
  end

  def filter_options(_params), do: []

  def type_filter_options(%{"type" => type}) do
    parse_filter(type, @allowed_type_labels)
  end

  def type_filter_options(_params), do: []

  def method_filter_options(%{"method" => method}) do
    parse_method_filter(method)
  end

  def method_filter_options(_params), do: []

  def parse_filter("[" <> filter, allowed_labels) do
    filter
    |> String.trim_trailing("]")
    |> parse_filter(allowed_labels)
  end

  def parse_filter(filter, allowed_labels) when is_binary(filter) do
    filter
    |> String.split(",")
    |> Enum.filter(fn label -> Enum.member?(allowed_labels, label) end)
    |> Enum.map(&String.to_atom/1)
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
end
