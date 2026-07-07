# SPDX-License-Identifier: LicenseRef-Blockscout
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

  describe "delete_parameters_from_next_page_params/1" do
    test "removes :key (atom) from params" do
      params = %{key: "mysecret", block_number: 42, index: 0}
      result = PagingHelper.delete_parameters_from_next_page_params(params)
      refute Map.has_key?(result, :key)
      assert Map.has_key?(result, :block_number)
    end

    test "removes \"key\" (string) from params" do
      params = %{"key" => "mysecret", "block_number" => "42", "index" => "0"}
      result = PagingHelper.delete_parameters_from_next_page_params(params)
      refute Map.has_key?(result, "key")
      assert Map.has_key?(result, "block_number")
    end

    test "removes :apikey (atom) from params" do
      params = %{apikey: "myapikey", block_number: 42}
      result = PagingHelper.delete_parameters_from_next_page_params(params)
      refute Map.has_key?(result, :apikey)
      assert Map.has_key?(result, :block_number)
    end

    test "removes \"apikey\" (string) from params" do
      params = %{"apikey" => "myapikey", "block_number" => "42"}
      result = PagingHelper.delete_parameters_from_next_page_params(params)
      refute Map.has_key?(result, "apikey")
      assert Map.has_key?(result, "block_number")
    end

    test "removes both :key and :apikey when both present" do
      params = %{key: "mysecret", apikey: "myapikey", block_number: 42}
      result = PagingHelper.delete_parameters_from_next_page_params(params)
      refute Map.has_key?(result, :key)
      refute Map.has_key?(result, :apikey)
      assert Map.has_key?(result, :block_number)
    end

    test "preserves unrelated pagination params" do
      params = %{"block_number" => "100", "index" => "5"}
      result = PagingHelper.delete_parameters_from_next_page_params(params)
      assert result == params
    end

    test "returns nil for non-map input" do
      assert PagingHelper.delete_parameters_from_next_page_params(nil) == nil
      assert PagingHelper.delete_parameters_from_next_page_params("string") == nil
    end
  end
end
