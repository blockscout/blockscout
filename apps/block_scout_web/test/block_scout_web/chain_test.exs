defmodule BlockScoutWeb.ChainTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Address, Block, Transaction, TokenTransfer}
  alias Explorer.PagingOptions
  alias BlockScoutWeb.Chain

  describe "paginate_list/3" do
    test "returns all items and nil when list is shorter than page_size" do
      paging_options = %PagingOptions{page_size: 11}
      items = Enum.to_list(1..5)

      assert {^items, nil} = Chain.paginate_list(items, %{}, paging_options)
    end

    test "splits list and generates next_page_params when list has overflow" do
      paging_options = %PagingOptions{page_size: 3}
      items = [%{id: 3}, %{id: 2}, %{id: 1}]

      {result, next_page_params} = Chain.paginate_list(items, %{}, paging_options, paging_function: fn item -> item end)

      assert result == [%{id: 3}, %{id: 2}]
      assert next_page_params == %{id: 2}
    end

    test "returns empty list and nil for empty input" do
      paging_options = %PagingOptions{page_size: 11}
      assert {[], nil} = Chain.paginate_list([], %{}, paging_options)
    end

    test "strips items_count from next_page_params" do
      paging_options = %PagingOptions{page_size: 2}
      items = [%{id: 2}, %{id: 1}]

      {_result, next_page_params} =
        Chain.paginate_list(items, %{items_count: 10}, paging_options, paging_function: fn item -> item end)

      refute Map.has_key?(next_page_params, :items_count)
      refute Map.has_key?(next_page_params, "items_count")
    end
  end

  describe "token_transfers_next_page_params/3" do
    # https://github.com/blockscout/blockscout/issues/12984
    test "does not return duplicated keys" do
      paging_options = %PagingOptions{page_size: 2}

      {_items, next_page_params} =
        Chain.token_transfers_next_page_params(
          [
            %TokenTransfer{block_number: 1, log_index: 2},
            %TokenTransfer{block_number: 1, log_index: 3}
          ],
          %{
            "block_number" => 5,
            "index" => 4
          },
          paging_options
        )

      assert next_page_params == %{
               block_number: 1,
               index: 2
             }
    end

    test "does not return duplicated keys with batch transfer" do
      paging_options = %PagingOptions{page_size: 3}

      {_items, next_page_params} =
        Chain.token_transfers_next_page_params(
          [
            %TokenTransfer{
              block_number: 1,
              log_index: 2,
              block_hash: "0xabc",
              transaction_hash: "0xdef",
              index_in_batch: 3
            },
            %TokenTransfer{
              block_number: 1,
              log_index: 2,
              block_hash: "0x123",
              transaction_hash: "0x456",
              index_in_batch: 2
            },
            %TokenTransfer{
              block_number: 1,
              log_index: 2,
              block_hash: "0x123",
              transaction_hash: "0x456",
              index_in_batch: 1
            }
          ],
          %{
            "block_number" => 5,
            "index" => 4,
            "batch_log_index" => 3,
            "batch_block_hash" => "0x789",
            "batch_transaction_hash" => "0xabc",
            "index_in_batch" => 2
          },
          paging_options
        )

      assert next_page_params == %{
               block_number: 1,
               index: 2,
               batch_block_hash: "0x123",
               batch_log_index: 2,
               batch_transaction_hash: "0x456",
               index_in_batch: 2
             }
    end
  end

  describe "current_filter/1" do
    test "sets direction based on to filter" do
      assert [direction: :to] = Chain.current_filter(%{"filter" => "to"})
    end

    test "sets direction based on from filter" do
      assert [direction: :from] = Chain.current_filter(%{"filter" => "from"})
    end

    test "no direction set" do
      assert [] = Chain.current_filter(%{})
    end

    test "no direction set with paging_options" do
      assert [paging_options: "test"] = Chain.current_filter(%{paging_options: "test"})
    end
  end

  describe "from_param/1" do
    test "finds a block by block number with a valid block number" do
      %Block{number: number} = insert(:block, number: 37)

      assert {:ok, %Block{number: ^number}} =
               number
               |> to_string()
               |> Chain.from_param()
    end

    test "finds a transaction by hash string" do
      transaction = %Transaction{hash: hash} = insert(:transaction)

      assert {:ok, %Transaction{hash: ^hash}} = transaction |> Phoenix.Param.to_param() |> Chain.from_param()
    end

    test "finds an address by hash string" do
      address = %Address{hash: hash} = insert(:address)

      assert {:ok, %Address{hash: ^hash}} = address |> Phoenix.Param.to_param() |> Chain.from_param()
    end

    test "returns {:error, :not_found} when garbage is passed in" do
      assert {:error, :not_found} = Chain.from_param("any ol' thing")
    end

    test "returns {:error, :not_found} when it does not find a match" do
      transaction_hash = String.pad_trailing("0xnonsense", 43, "0")
      address_hash = String.pad_trailing("0xbaddress", 42, "0")

      assert {:error, :not_found} = Chain.from_param("38999")
      assert {:error, :not_found} = Chain.from_param(transaction_hash)
      assert {:error, :not_found} = Chain.from_param(address_hash)
    end
  end

  describe "Jason.encode!" do
    test "correctly encodes decimal values" do
      val = Decimal.from_float(5.55)

      assert "\"5.55\"" == Jason.encode!(val)
    end
  end
end
