defmodule Explorer.Chain.CsvExport.Helper do
  @moduledoc """
  CSV export helper functions.
  """

  alias Explorer.Chain.Block
  alias Explorer.Chain.Block.Reader.General, as: BlockGeneralReader
  alias Explorer.Chain.Hash.Full, as: Hash
  alias Explorer.PagingOptions
  alias NimbleCSV.RFC4180

  import Ecto.Query,
    only: [
      where: 3
    ]

  @page_size 150
  @default_paging_options %PagingOptions{page_size: @page_size}

  def dump_to_stream(items) do
    items
    |> RFC4180.dump_to_stream()
  end

  def page_size, do: @page_size

  def default_paging_options, do: @default_paging_options

  @spec limit() :: integer()
  def limit, do: Application.get_env(:explorer, :csv_export_limit)

  @spec paging_options() :: Explorer.PagingOptions.t()
  def paging_options, do: %PagingOptions{page_size: limit()}

  @doc """
  Returns a tuple containing the minimum block number from the `from_period` and the maximum block number from the `to_period`.

  ## Parameters

  - `from_period`: The starting period, which can be an ISO8601 timestamp or a date string, from which to calculate the minimum block number.
  - `to_period`: The ending period, which can be an ISO8601 timestamp or a date string, from which to calculate the maximum block number.

  ## Returns

  - A tuple `{from_block, to_block}` where `from_block` is the minimum block number from the `from_period` and `to_block` is the maximum block number from the `to_period`.

  ## Examples

    iex> block_from_period("2023-01-01T00:00:00Z", "2023-12-31T23:59:59Z")
    {1000, 2000}

    iex> block_from_period("2023-01-01", "2023-12-31")
    {1000, 2000}

  """
  @spec block_from_period(String.t(), String.t()) :: {Block.block_number(), Block.block_number()}
  def block_from_period(from_period, to_period) do
    from_block = convert_date_string_to_block(from_period, :after, :from)
    to_block = convert_date_string_to_block(to_period, :before, :to)

    {from_block, to_block}
  end

  @spec convert_date_string_to_block(String.t(), :before | :after, :from | :to) :: integer()
  defp convert_date_string_to_block(date_string, direction, range_type) do
    with {:ok, timestamp, _utc_offset} <- date_string_to_timestamp(date_string, range_type),
         {:ok, block} <- BlockGeneralReader.timestamp_to_block_number(timestamp, direction, true) do
      block
    else
      _ -> 0
    end
  end

  @spec date_string_to_timestamp(String.t(), :from | :to) ::
          {:ok, DateTime.t(), Calendar.utc_offset()} | {:error, atom()}
  defp date_string_to_timestamp(date_string, range_type) do
    date_string
    |> Date.from_iso8601()
    |> case do
      {:ok, _date} ->
        range_time =
          case range_type do
            :from -> "T00:00:00Z"
            :to -> "T23:59:59Z"
          end

        date_string <> range_time

      _ ->
        date_string
    end
    |> DateTime.from_iso8601()
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

  @spec valid_filter?(String.t(), String.t(), String.t()) :: boolean()
  def valid_filter?(filter_type, filter_value, item_type) do
    valid_filter_type?(filter_type, filter_value, item_type) && valid_filter_value?(filter_type, filter_value)
  end

  defp valid_filter_type?(filter_type, filter_value, item_type) do
    filter_type in supported_filters(item_type) && filter_value && filter_value !== ""
  end

  defp valid_filter_value?(filter_type, filter_value) do
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
