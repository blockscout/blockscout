defmodule BlockScoutWeb.GenericPaginationHelpers do
  @moduledoc """
  Helpers for handling pagination
  """

  def next_page_path(
        _conn,
        %{page_number: page_number, page_size: page_size},
        total_item_count,
        _path_fun
      )
      when page_number * page_size >= total_item_count,
      do: nil

  def next_page_path(
        conn,
        %{page_number: page_number} = params,
        _total_item_count,
        path_fun
      ),
      do: path_fun.(conn, %{params | page_number: page_number + 1})

  def prev_page_path(_conn, %{page_number: 1}, _path_fun), do: nil

  def prev_page_path(conn, %{page_number: page_number} = params, path_fun),
    do: path_fun.(conn, %{params | page_number: page_number - 1})

  def first_page_path(_conn, %{page_number: 1}, _path_fun), do: nil

  def first_page_path(conn, params, path_fun), do: path_fun.(conn, %{params | page_number: 1})

  def last_page_path(_conn, %{page_size: page_size, page_number: page_number}, total_item_count, _path_fun)
      when ceil(total_item_count / page_size) == page_number,
      do: nil

  def last_page_path(conn, %{page_size: page_size} = params, total_item_count, path_fun),
    do: path_fun.(conn, %{params | page_number: ceil(total_item_count / page_size)})

  def current_page(%{page_number: page_number}), do: page_number

  def sort_path(
        conn,
        %{order_field: order_field, order_dir: order_dir} = params,
        field,
        default_order_dir,
        path_fun
      ),
      do:
        path_fun.(
          conn,
          Map.merge(
            params,
            if order_field == field do
              if order_dir == "desc", do: %{order_dir: "asc"}, else: %{order_dir: "desc"}
            else
              %{order_field: field, order_dir: default_order_dir}
            end
          )
        )
end
