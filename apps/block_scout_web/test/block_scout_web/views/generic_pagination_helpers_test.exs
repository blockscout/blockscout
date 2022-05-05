defmodule BlockScoutWeb.GenericPaginationHelpersTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.GenericPaginationHelpers

  describe "next_page_path/3" do
    test "returns nil when there's no next page", %{conn: conn} do
      assert nil == GenericPaginationHelpers.next_page_path(conn, %{page_number: 2, page_size: 10}, 20, nil)
    end

    test "returns next page", %{conn: conn} do
      path_fun = fn _conn, %{page_number: page_number} -> "/mock?page_number=#{page_number}" end

      assert "/mock?page_number=3" ==
               GenericPaginationHelpers.next_page_path(conn, %{page_number: 2, page_size: 10}, 30, path_fun)
    end
  end

  describe "prev_page_path/3" do
    test "returns nil when there's no prev page", %{conn: conn} do
      assert nil == GenericPaginationHelpers.prev_page_path(conn, %{page_number: 1}, nil)
    end

    test "returns prev page path", %{conn: conn} do
      path_fun = fn _conn, %{page_number: page_number} -> "/mock?page_number=#{page_number}" end

      assert "/mock?page_number=2" == GenericPaginationHelpers.prev_page_path(conn, %{page_number: 3}, path_fun)
    end
  end

  describe "first_page_path/3" do
    test "returns nil when it's already first page", %{conn: conn} do
      assert nil == GenericPaginationHelpers.first_page_path(conn, %{page_number: 1}, nil)
    end

    test "returns first page path", %{conn: conn} do
      path_fun = fn _conn, %{page_number: page_number} -> "/mock?page_number=#{page_number}" end

      assert "/mock?page_number=1" == GenericPaginationHelpers.first_page_path(conn, %{page_number: 3}, path_fun)
    end
  end

  describe "last_page_path/4" do
    test "returns nil when it's already last page", %{conn: conn} do
      assert nil == GenericPaginationHelpers.last_page_path(conn, %{page_number: 3, page_size: 10}, 30, nil)
    end

    test "returns last page path", %{conn: conn} do
      path_fun = fn _conn, %{page_number: page_number} -> "/mock?page_number=#{page_number}" end

      assert "/mock?page_number=5" ==
               GenericPaginationHelpers.last_page_path(conn, %{page_number: 3, page_size: 10}, 50, path_fun)
    end
  end

  describe "current_page/1" do
    test "returns current page" do
      assert 3 == GenericPaginationHelpers.current_page(%{page_number: 3})
    end
  end

  describe "sort_path/4" do
    test "provides sort path for a field", %{conn: conn} do
      path_fun = fn _conn, %{order_field: order_field, order_dir: order_dir} ->
        "/mock?order_field=#{order_field}&order_dir=#{order_dir}"
      end

      assert "/mock?order_field=name&order_dir=asc" ==
               GenericPaginationHelpers.sort_path(conn, %{order_field: nil, order_dir: "desc"}, "name", "asc", path_fun)

      assert "/mock?order_field=name&order_dir=asc" ==
               GenericPaginationHelpers.sort_path(
                 conn,
                 %{order_field: "different", order_dir: "asc"},
                 "name",
                 "asc",
                 path_fun
               )
    end

    test "inverts sort dir for a field", %{conn: conn} do
      path_fun = fn _conn, %{order_field: order_field, order_dir: order_dir} ->
        "/mock?order_field=#{order_field}&order_dir=#{order_dir}"
      end

      assert "/mock?order_field=name&order_dir=desc" ==
               GenericPaginationHelpers.sort_path(
                 conn,
                 %{order_field: "name", order_dir: "asc"},
                 "name",
                 "asc",
                 path_fun
               )

      assert "/mock?order_field=name&order_dir=asc" ==
               GenericPaginationHelpers.sort_path(
                 conn,
                 %{order_field: "name", order_dir: "desc"},
                 "name",
                 "asc",
                 path_fun
               )
    end
  end
end
