defmodule Explorer.GenericPagingOptions do
  @moduledoc """
  Defines generic paging options for paging by any key.
  """

  @type generic_paging_options :: {
          order_field :: String.t() | nil,
          order_dir :: String.t() | nil,
          page_size :: non_neg_integer(),
          page_number :: pos_integer()
        }

  def extract_paging_options_from_params(
        params,
        total_item_count,
        allowed_order_fields,
        default_order_dir,
        max_page_size
      ) do
    uniformed_params = params |> uniform_params
    page_size = extract_page_size(uniformed_params, max_page_size)

    %{
      order_field: extract_order_field(uniformed_params, allowed_order_fields),
      order_dir: extract_order_dir(uniformed_params, default_order_dir),
      page_size: page_size,
      page_number: extract_page_number(uniformed_params, ceil(total_item_count / page_size))
    }
  end

  def extract_paging_options_from_params(
        params,
        max_page_size
      ) do
    uniformed_params = params |> uniform_params

    %{
      order_field: nil,
      order_dir: nil,
      page_size: extract_page_size(uniformed_params, max_page_size),
      page_number: extract_page_number(uniformed_params)
    }
  end

  defp extract_page_size(%{"page_size" => page_size}, max_page_size) when is_bitstring(page_size) do
    case Integer.parse(page_size) do
      {page_size, _} when page_size > max_page_size or page_size < 1 ->
        max_page_size

      {page_size, _} ->
        page_size

      :error ->
        max_page_size
    end
  end

  defp extract_page_size(_, max_page_size), do: max_page_size

  defp extract_page_number(%{"page_number" => _}, 0), do: 1

  defp extract_page_number(%{"page_number" => page_number}, total_page_count) when is_bitstring(page_number) do
    case Integer.parse(page_number) do
      {page_number, _} when page_number > total_page_count ->
        min(total_page_count, page_number)

      {page_number, _} ->
        page_number |> filter_non_negative_page_number

      :error ->
        1
    end
  end

  defp extract_page_number(_, _), do: 1

  defp extract_page_number(%{"page_number" => page_number}) when is_bitstring(page_number) do
    case Integer.parse(page_number) do
      {page_number, _} -> page_number |> filter_non_negative_page_number
      :error -> 1
    end
  end

  defp extract_page_number(_), do: 1

  defp extract_order_field(%{"order_field" => order_field}, allowed_order_fields) when is_list(allowed_order_fields),
    do: if(Enum.member?(allowed_order_fields, order_field), do: order_field, else: Enum.at(allowed_order_fields, 0))

  defp extract_order_field(%{}, [default_order_field | _]), do: default_order_field
  defp extract_order_field(_, _), do: nil

  defp extract_order_dir(%{"order_dir" => order_dir}, _) when order_dir == "desc" or order_dir == "asc", do: order_dir
  defp extract_order_dir(_, default_order_dir), do: default_order_dir

  defp filter_non_negative_page_number(page_number) when page_number < 1, do: 1
  defp filter_non_negative_page_number(page_number), do: page_number

  defp uniform_params(params) do
    %{
      "order_field" => Map.get(params, "orderField", Map.get(params, "order_field")),
      "order_dir" => Map.get(params, "orderDir", Map.get(params, "order_dir")),
      "page_size" => Map.get(params, "pageSize", Map.get(params, "page_size")),
      "page_number" => Map.get(params, "pageNumber", Map.get(params, "page_number"))
    }
  end
end
