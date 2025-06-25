defmodule Explorer.SortingHelper do
  @moduledoc """
  Module that order and paginate queries dynamically based on default and provided sorting parameters.
  Example of sorting parameters:
  ```
  [{:asc, :fetched_coin_balance, :address}, {:dynamic, :contract_code_size, :desc, dynamic([t], fragment(LENGTH(?), t.contract_source_code))}, desc: :id]
  ```
  First list entry specify joined address table column as a column to order by and paginate, second entry
  specifies name of a key in paging_options and arbitrary dynamic that will be used in ordering and pagination,
  third entry specifies own column name to order by and paginate.
  """
  alias Explorer.PagingOptions

  import Ecto.Query

  @typep ordering :: :asc | :asc_nulls_first | :asc_nulls_last | :desc | :desc_nulls_first | :desc_nulls_last
  @typep column :: atom
  @typep binding :: atom
  @type sorting_params :: [
          {ordering, column} | {ordering, column, binding} | {:dynamic, column, ordering, Ecto.Query.dynamic_expr()}
        ]

  @doc """
  Applies sorting to query based on default sorting params and sorting params from the client,
  these params merged keeping provided one over default one.
  """
  @spec apply_sorting(Ecto.Query.t() | module(), sorting_params, sorting_params) :: Ecto.Query.t()
  def apply_sorting(query, sorting, default_sorting) when is_list(sorting) and is_list(default_sorting) do
    sorting |> merge_sorting_params_with_defaults(default_sorting) |> sorting_params_to_order_by(query)
  end

  defp merge_sorting_params_with_defaults([], default_sorting) when is_list(default_sorting), do: default_sorting

  defp merge_sorting_params_with_defaults(sorting, default_sorting)
       when is_list(sorting) and is_list(default_sorting) do
    (sorting ++ default_sorting)
    |> Enum.uniq_by(fn
      {_, field} -> field
      {_, field, as} -> {field, as}
      {:dynamic, key_name, _, _} -> key_name
    end)
  end

  defp sorting_params_to_order_by(sorting_params, query) do
    sorting_params
    |> Enum.reduce(query, fn
      {:dynamic, _key_name, order, dynamic}, query -> query |> order_by(^[{order, dynamic}])
      {order, column, binding}, query -> query |> order_by([{^order, field(as(^binding), ^column)}])
      {order, column}, query -> query |> order_by(^[{order, column}])
    end)
  end

  @doc """
  Page the query based on paging options, default sorting params and sorting params from the client,
  these params merged keeping provided one over default one.
  """
  @spec page_with_sorting(Ecto.Query.t(), PagingOptions.t(), sorting_params, sorting_params) :: Ecto.Query.t()
  def page_with_sorting(query, %PagingOptions{key: key, page_size: page_size}, sorting, default_sorting)
      when not is_nil(key) do
    sorting
    |> merge_sorting_params_with_defaults(default_sorting)
    |> do_page_with_sorting()
    |> case do
      nil -> query
      dynamic_where -> query |> where(^dynamic_where.(key))
    end
    |> limit_query(page_size)
  end

  def page_with_sorting(query, %PagingOptions{page_size: page_size}, _sorting, _default_sorting) do
    query |> limit_query(page_size)
  end

  def page_with_sorting(query, _, _sorting, _default_sorting), do: query

  defp limit_query(query, limit) when is_integer(limit), do: query |> limit(^limit)
  defp limit_query(query, _), do: query

  defp do_page_with_sorting([{order, column} | rest]) do
    fn key -> page_by_column(key, column, order, do_page_with_sorting(rest)) end
  end

  defp do_page_with_sorting([{:dynamic, key_name, order, dynamic} | rest]) do
    fn key -> page_by_column(key, {:dynamic, key_name, dynamic}, order, do_page_with_sorting(rest)) end
  end

  defp do_page_with_sorting([{order, column, binding} | rest]) do
    fn key -> page_by_column(key, {column, binding}, order, do_page_with_sorting(rest)) end
  end

  defp do_page_with_sorting([]), do: nil

  for {key_name, pattern, ecto_value} <- [
        {quote(do: key_name), quote(do: {:dynamic, key_name, dynamic}), quote(do: ^dynamic)},
        {quote(do: column), quote(do: {column, binding}), quote(do: field(as(^binding), ^column))},
        {quote(do: column), quote(do: column), quote(do: field(t, ^column))}
      ] do
    defp page_by_column(key, unquote(pattern), :desc_nulls_last, next_column) do
      case key[unquote(key_name)] do
        nil ->
          dynamic([t], is_nil(unquote(ecto_value)) and ^apply_next_column(next_column, key))

        value ->
          dynamic(
            [t],
            is_nil(unquote(ecto_value)) or unquote(ecto_value) < ^value or
              (unquote(ecto_value) == ^value and ^apply_next_column(next_column, key))
          )
      end
    end

    defp page_by_column(key, unquote(pattern), :asc_nulls_first, next_column) do
      case key[unquote(key_name)] do
        nil ->
          dynamic([t], not is_nil(unquote(ecto_value)) or ^apply_next_column(next_column, key))

        value ->
          dynamic(
            [t],
            not is_nil(unquote(ecto_value)) and
              (unquote(ecto_value) > ^value or
                 (unquote(ecto_value) == ^value and ^apply_next_column(next_column, key)))
          )
      end
    end

    defp page_by_column(key, unquote(pattern), order, next_column) when order in ~w(asc asc_nulls_last)a do
      case key[unquote(key_name)] do
        nil ->
          dynamic([t], is_nil(unquote(ecto_value)) and ^apply_next_column(next_column, key))

        value ->
          dynamic(
            [t],
            is_nil(unquote(ecto_value)) or
              (unquote(ecto_value) > ^value or
                 (unquote(ecto_value) == ^value and ^apply_next_column(next_column, key)))
          )
      end
    end

    defp page_by_column(key, unquote(pattern), order, next_column)
         when order in ~w(desc desc_nulls_first)a do
      case key[unquote(key_name)] do
        nil ->
          dynamic([t], not is_nil(unquote(ecto_value)) or ^apply_next_column(next_column, key))

        value ->
          dynamic(
            [t],
            not is_nil(unquote(ecto_value)) and
              (unquote(ecto_value) < ^value or
                 (unquote(ecto_value) == ^value and ^apply_next_column(next_column, key)))
          )
      end
    end
  end

  defp apply_next_column(nil, _key) do
    false
  end

  defp apply_next_column(next_column, key) do
    next_column.(key)
  end
end
