defmodule BlockScoutWeb.PagingHelperTest do
  use ExUnit.Case, async: true

  alias BlockScoutWeb.PagingHelper
  alias Explorer.PagingOptions

  describe "paging_options/2 items_count support" do
    test "overrides page_size when items_count is present" do
      params = %{items_count: 10, block_number: 100, index: 5}
      [paging_options: paging_options] = PagingHelper.paging_options(params, [:validated])

      assert %PagingOptions{page_size: 11} = paging_options
    end

    test "clamps items_count to max_page_size" do
      params = %{items_count: 99999, block_number: 100, index: 5}
      [paging_options: paging_options] = PagingHelper.paging_options(params, [:validated])

      expected_page_size = PagingOptions.max_page_size() + 1
      assert %PagingOptions{page_size: ^expected_page_size} = paging_options
    end

    test "uses default page_size when items_count is absent" do
      params = %{block_number: 100, index: 5}
      [paging_options: paging_options] = PagingHelper.paging_options(params, [:validated])

      assert %PagingOptions{page_size: 51} = paging_options
    end

    test "ignores items_count when zero or negative" do
      params = %{items_count: 0, block_number: 100, index: 5}
      [paging_options: paging_options] = PagingHelper.paging_options(params, [:validated])

      assert %PagingOptions{page_size: 51} = paging_options
    end

    test "works with catch-all clause" do
      params = %{items_count: 25}
      [paging_options: paging_options] = PagingHelper.paging_options(params, [:validated])

      assert %PagingOptions{page_size: 26} = paging_options
    end
  end
end
