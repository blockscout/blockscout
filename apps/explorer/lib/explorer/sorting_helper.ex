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
  require Explorer.SortingHelper

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
  @spec apply_sorting(Ecto.Query.t(), sorting_params, sorting_params) :: Ecto.Query.t()
  def apply_sorting(query, sorting, default_sorting) when is_list(sorting) and is_list(default_sorting) do
    sorting |> sorting_with_defaults(default_sorting) |> apply_as(query)
  end

  defp sorting_with_defaults([], default_sorting) when is_list(default_sorting), do: default_sorting

  defp sorting_with_defaults(sorting, default_sorting) when is_list(sorting) and is_list(default_sorting) do
    (sorting ++ default_sorting)
    |> Enum.uniq_by(fn
      {_, field} -> field
      {_, field, as} -> {field, as}
      {:dynamic, key_name, _, _} -> key_name
    end)
  end

  defp apply_as(sorting, query) do
    sorting
    |> Enum.reduce(query, fn
      {:dynamic, _key_name, order, dynamic}, query -> query |> order_by(^[{order, dynamic}])
      {order, column, binding}, query -> query |> order_by([{^order, field(as(^binding), ^column)}])
      no_binding, query -> query |> order_by(^[no_binding])
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
    |> sorting_with_defaults(default_sorting)
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

  # we could use here some function like
  # defp apply_column({column, binding}) do
  #   dynamic([t], field(as(^binding), ^column))
  # end
  #
  # defp apply_column(column) do
  #   dynamic([t], field(t, ^column))
  # end
  # but ecto does not support dynamic fields like that,
  # related issue: https://github.com/elixir-ecto/ecto/issues/4186
  # possible solution is to define macro that will generate case and replace some placeholder value in
  # dynamic based on which case clause we get, but now it seems like overengineering
  defp page_by_column(key, {:dynamic, key_name, dynamic}, :desc_nulls_last, next_column) do
    case key[key_name] do
      nil ->
        dynamic([t], is_nil(^dynamic) and ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          is_nil(^dynamic) or ^dynamic < ^value or
            (^dynamic == ^value and ^apply_next_column(next_column, key))
        )
    end
  end

  defp page_by_column(key, {:dynamic, key_name, dynamic}, :asc_nulls_first, next_column) do
    case key[key_name] do
      nil ->
        dynamic([t], not is_nil(^dynamic) or ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          not is_nil(^dynamic) and
            (^dynamic > ^value or
               (^dynamic == ^value and ^apply_next_column(next_column, key)))
        )
    end
  end

  defp page_by_column(key, {:dynamic, key_name, dynamic}, order, next_column) when order in ~w(asc asc_nulls_last)a do
    case key[key_name] do
      nil ->
        dynamic([t], is_nil(^dynamic) and ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          is_nil(^dynamic) or
            (^dynamic > ^value or
               (^dynamic == ^value and ^apply_next_column(next_column, key)))
        )
    end
  end

  defp page_by_column(key, {:dynamic, key_name, dynamic}, order, next_column)
       when order in ~w(desc desc_nulls_first)a do
    case key[key_name] do
      nil ->
        dynamic([t], not is_nil(^dynamic) or ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          not is_nil(^dynamic) and
            (^dynamic < ^value or
               (^dynamic == ^value and ^apply_next_column(next_column, key)))
        )
    end
  end

  defp page_by_column(key, {column, binding}, :desc_nulls_last, next_column) do
    case key[column] do
      nil ->
        dynamic([t], is_nil(field(as(^binding), ^column)) and ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          is_nil(field(as(^binding), ^column)) or field(as(^binding), ^column) < ^value or
            (field(as(^binding), ^column) == ^value and ^apply_next_column(next_column, key))
        )
    end
  end

  defp page_by_column(key, {column, binding}, :asc_nulls_first, next_column) do
    case key[column] do
      nil ->
        dynamic([t], not is_nil(field(as(^binding), ^column)) or ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          not is_nil(field(as(^binding), ^column)) and
            (field(as(^binding), ^column) > ^value or
               (field(as(^binding), ^column) == ^value and ^apply_next_column(next_column, key)))
        )
    end
  end

  defp page_by_column(key, {column, binding}, order, next_column) when order in ~w(asc asc_nulls_last)a do
    case key[column] do
      nil ->
        dynamic([t], is_nil(field(as(^binding), ^column)) and ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          is_nil(field(as(^binding), ^column)) or
            (field(as(^binding), ^column) > ^value or
               (field(as(^binding), ^column) == ^value and ^apply_next_column(next_column, key)))
        )
    end
  end

  defp page_by_column(key, {column, binding}, order, next_column) when order in ~w(desc desc_nulls_first)a do
    case key[column] do
      nil ->
        apply_next_column(next_column, key)

      value ->
        dynamic(
          [t],
          not is_nil(field(as(^binding), ^column)) and
            (field(as(^binding), ^column) < ^value or
               (field(as(^binding), ^column) == ^value and ^apply_next_column(next_column, key)))
        )
    end
  end

  defp page_by_column(key, column, :desc_nulls_last, next_column) do
    case key[column] do
      nil ->
        dynamic([t], is_nil(field(t, ^column)) and ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          is_nil(field(t, ^column)) or field(t, ^column) < ^value or
            (field(t, ^column) == ^value and ^apply_next_column(next_column, key))
        )
    end
  end

  defp page_by_column(key, column, :asc_nulls_first, next_column) do
    case key[column] do
      nil ->
        apply_next_column(next_column, key)

      value ->
        dynamic(
          [t],
          not is_nil(field(t, ^column)) and
            (field(t, ^column) > ^value or
               (field(t, ^column) == ^value and ^apply_next_column(next_column, key)))
        )
    end
  end

  defp page_by_column(key, column, order, next_column) when order in ~w(asc asc_nulls_last)a do
    case key[column] do
      nil ->
        dynamic([t], is_nil(field(t, ^column)) and ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          is_nil(field(t, ^column)) or
            (field(t, ^column) > ^value or
               (field(t, ^column) == ^value and ^apply_next_column(next_column, key)))
        )
    end
  end

  defp page_by_column(key, column, order, next_column) when order in ~w(desc desc_nulls_first)a do
    case key[column] do
      nil ->
        dynamic([t], not is_nil(field(t, ^column)) or ^apply_next_column(next_column, key))

      value ->
        dynamic(
          [t],
          not is_nil(field(t, ^column)) and
            (field(t, ^column) < ^value or
               (field(t, ^column) == ^value and ^apply_next_column(next_column, key)))
        )
    end
  end

  defp apply_next_column(nil, _key) do
    false
  end

  defp apply_next_column(next_column, key) do
    next_column.(key)
  end
end
