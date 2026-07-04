# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.PagingHelperTest do
  use ExUnit.Case, async: true

  alias BlockScoutWeb.PagingHelper

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
      params = %{key: "mysecret", apikey: "myapikey", items_count: 50}
      result = PagingHelper.delete_parameters_from_next_page_params(params)
      refute Map.has_key?(result, :key)
      refute Map.has_key?(result, :apikey)
      assert Map.has_key?(result, :items_count)
    end

    test "preserves unrelated pagination params" do
      params = %{"block_number" => "100", "index" => "5", "items_count" => "50"}
      result = PagingHelper.delete_parameters_from_next_page_params(params)
      assert result == params
    end

    test "returns nil for non-map input" do
      assert PagingHelper.delete_parameters_from_next_page_params(nil) == nil
      assert PagingHelper.delete_parameters_from_next_page_params("string") == nil
    end
  end
end
