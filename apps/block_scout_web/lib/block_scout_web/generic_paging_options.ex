defmodule BlockScoutWeb.GenericPagingOptions do
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
        default_page_size
      ) do
    page_size = extract_page_size(params, default_page_size)

    %{
      order_field: extract_order_field(params, allowed_order_fields),
      order_dir: extract_order_dir(params, default_order_dir),
      page_size: page_size,
      page_number: extract_page_number(params, ceil(total_item_count / page_size))
    }
  end

  defp extract_page_size(%{"page_size" => page_size}, default_page_size) when is_bitstring(page_size) do
    case Integer.parse(page_size) do
      {page_size, _} -> page_size
      :error -> default_page_size
    end
  end

  defp extract_page_size(_, default_page_size), do: default_page_size

  defp extract_page_number(%{"page_number" => page_number}, total_page_count) when is_bitstring(page_number) do
    case Integer.parse(page_number) do
      {page_number, _} -> if page_number > total_page_count, do: min(total_page_count, page_number), else: page_number
      :error -> 1
    end
  end

  defp extract_page_number(_, _), do: 1

  defp extract_order_field(%{"order_field" => order_field}, allowed_order_fields) when is_list(allowed_order_fields),
    do: if(Enum.member?(allowed_order_fields, order_field), do: order_field, else: Enum.at(allowed_order_fields, 0))

  defp extract_order_field(%{}, [default_order_field | _]), do: default_order_field
  defp extract_order_field(_, _), do: nil

  defp extract_order_dir(%{"order_dir" => order_dir}, _) when order_dir == "desc" or order_dir == "asc", do: order_dir
  defp extract_order_dir(_, default_order_dir), do: default_order_dir
end
