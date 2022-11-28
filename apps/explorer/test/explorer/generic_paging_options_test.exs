defmodule Explorer.GenericPagingOptionsTest do
  use Explorer.DataCase

  alias Explorer.GenericPagingOptions

  describe "extract_paging_options_from_params/4" do
    test "provides default values for no order fields" do
      assert %{
               order_dir: "desc",
               order_field: nil,
               page_number: 1,
               page_size: 10
             } == GenericPagingOptions.extract_paging_options_from_params(%{}, 10, [], "desc", 10)
    end

    test "provides default values for one order field" do
      assert %{
               order_dir: "asc",
               order_field: "count",
               page_number: 1,
               page_size: 20
             } == GenericPagingOptions.extract_paging_options_from_params(%{}, 20, ["count"], "asc", 20)
    end

    test "provides default value for wrong page number type" do
      assert %{
               order_dir: "asc",
               order_field: "count",
               page_number: 1,
               page_size: 20
             } ==
               GenericPagingOptions.extract_paging_options_from_params(
                 %{
                   "page_number" => "invalid-value",
                   "page_size" => "invalid-value"
                 },
                 20,
                 ["count"],
                 "asc",
                 20
               )
    end

    test "provides max value for page number out of range" do
      assert %{
               order_dir: "asc",
               order_field: "count",
               page_number: 2,
               page_size: 20
             } ==
               GenericPagingOptions.extract_paging_options_from_params(
                 %{
                   "page_number" => "4",
                   "page_size" => "20"
                 },
                 30,
                 ["count"],
                 "asc",
                 30
               )
    end

    test "provides default values for multiple order fields" do
      assert %{
               order_dir: "asc",
               order_field: "count",
               page_number: 1,
               page_size: 20
             } == GenericPagingOptions.extract_paging_options_from_params(%{}, 20, ["count", "name"], "asc", 20)
    end

    test "provides default value when wrong order data provided in params" do
      assert %{
               order_dir: "asc",
               order_field: "count",
               page_number: 1,
               page_size: 20
             } ==
               GenericPagingOptions.extract_paging_options_from_params(
                 %{
                   "order_field" => "invalid-order-field",
                   "order_dir" => "invalid-order-dir"
                 },
                 20,
                 ["count", "name"],
                 "asc",
                 20
               )
    end

    test "overrides values when correct data provided in params" do
      assert %{
               order_dir: "desc",
               order_field: "name",
               page_number: 3,
               page_size: 5
             } ==
               GenericPagingOptions.extract_paging_options_from_params(
                 %{
                   "order_field" => "name",
                   "order_dir" => "desc",
                   "page_number" => "3",
                   "page_size" => "5"
                 },
                 30,
                 ["count", "name"],
                 "asc",
                 10
               )
    end

    test "provides default values for verified contracts page" do
      assert %{
               order_dir: "desc",
               order_field: "txns",
               page_number: 1,
               page_size: 10
             } ==
               GenericPagingOptions.extract_paging_options_from_params(
                 %{},
                 10,
                 ["txns", "name", "date"],
                 "desc",
                 10
               )
    end

    test "provides default values for verified contracts page when there are no contracts" do
      assert %{
               order_dir: "desc",
               order_field: "txns",
               page_number: 1,
               page_size: 10
             } ==
               GenericPagingOptions.extract_paging_options_from_params(
                 %{
                   "page_number" => "1"
                 },
                 0,
                 ["txns", "name", "date"],
                 "desc",
                 10
               )
    end

    test "does not allow to provide negative page number or page size" do
      assert %{
               order_dir: "desc",
               order_field: "txns",
               page_number: 1,
               page_size: 10
             } ==
               GenericPagingOptions.extract_paging_options_from_params(
                 %{
                   "page_number" => "-2",
                   "page_size" => "-1"
                 },
                 101,
                 ["txns", "name", "date"],
                 "desc",
                 10
               )
    end
  end

  describe "extract_paging_options_from_params/2" do
    test "does not allow to exceed default page size" do
      assert %{
               order_dir: nil,
               order_field: nil,
               page_number: 1,
               page_size: 100
             } ==
               GenericPagingOptions.extract_paging_options_from_params(
                 %{
                   "page_number" => "1",
                   "page_size" => "101"
                 },
                 100
               )
    end

    test "does not allow to provide negative page number or page size" do
      assert %{
               order_dir: nil,
               order_field: nil,
               page_number: 1,
               page_size: 100
             } ==
               GenericPagingOptions.extract_paging_options_from_params(
                 %{
                   "page_number" => "-1",
                   "page_size" => "-101"
                 },
                 100
               )
    end
  end
end
