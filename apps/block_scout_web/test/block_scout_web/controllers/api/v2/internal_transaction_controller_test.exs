# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.InternalTransactionControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  alias Explorer.Chain.{Address, InternalTransaction, PendingOperationsHelper}
  alias Explorer.Chain.Cache.BackgroundMigrations

  describe "/internal-transactions" do
    setup do
      BackgroundMigrations.set_heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished(
        true
      )

      :ok
    end

    test "empty list", %{conn: conn} do
      request = get(conn, "/api/v2/internal-transactions")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "returns pending status when internal transaction scope is pending", %{conn: conn} do
      request = get(conn, "/api/v2/internal-transactions")
      assert %{"items" => []} = json_response(request, 200)

      block = insert(:block)
      insert(:pending_block_operation, block_hash: block.hash, block_number: block.number)

      request = get(conn, "/api/v2/internal-transactions")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
      assert response["meta"]["status"] == 2

      assert response["meta"]["message"] ==
               "Some internal transactions within this block range have not yet been processed"
    end

    test "returns pending status when transaction hash is in pending_transaction_operations", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:pending_transaction_operation, transaction_hash: transaction.hash)

      request = get(conn, "/api/v2/internal-transactions", %{"transaction_hash" => to_string(transaction.hash)})

      assert response = json_response(request, 200)
      assert response["next_page_params"] == nil
      assert response["meta"]["status"] == 2

      assert response["meta"]["message"] ==
               "Some internal transactions within this block range have not yet been processed"
    end

    test "tolerates pending blocks within the chain head tolerance on the first page", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        transaction_index: 0,
        block_number: transaction.block_number,
        index: 1
      )

      # the pending block is one block inside the tolerance window, so it is ignored
      pending_block = insert(:block, number: transaction.block_number + 1)
      insert(:pending_block_operation, block_hash: pending_block.hash, block_number: pending_block.number)
      insert(:block, number: pending_block.number + pending_head_tolerance() - 1)

      request = get(conn, "/api/v2/internal-transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["meta"]["status"] == 1
      assert is_nil(response["meta"]["message"])

      # a listing filtered by transaction hash is bounded to that transaction, so the strict check
      # applies to its block even though the block is inside the tolerance window. The number of
      # items is not asserted: internal transactions of a pending block are hidden when pending
      # operations are tracked per block, which depends on the JSON RPC variant.
      insert(:pending_block_operation, block_hash: transaction.block_hash, block_number: transaction.block_number)

      request = get(conn, "/api/v2/internal-transactions", %{"transaction_hash" => to_string(transaction.hash)})

      assert response = json_response(request, 200)
      assert response["meta"]["status"] == 2

      assert response["meta"]["message"] ==
               "Some internal transactions within this block range have not yet been processed"
    end

    test "returns pending status for a pending block exactly tolerance blocks behind the chain head", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        transaction_index: 0,
        block_number: transaction.block_number,
        index: 1
      )

      pending_block = insert(:block, number: transaction.block_number + 1)
      insert(:pending_block_operation, block_hash: pending_block.hash, block_number: pending_block.number)
      insert(:block, number: pending_block.number + pending_head_tolerance())

      request = get(conn, "/api/v2/internal-transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["meta"]["status"] == 2

      assert response["meta"]["message"] ==
               "Some internal transactions within this block range have not yet been processed"

      # a following page is bounded by its paging parameters, so only its own block range is checked
      request =
        get(conn, "/api/v2/internal-transactions", %{
          "block_number" => "#{pending_block.number}",
          "transaction_index" => "0",
          "index" => "0"
        })

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["meta"]["status"] == 1
      assert is_nil(response["meta"]["message"])
    end

    test "non empty list", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: tx,
        transaction_index: 0,
        block_number: tx.block_number,
        index: 1
      )

      request = get(conn, "/api/v2/internal-transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
    end

    test "internal transactions with next_page_params", %{conn: conn} do
      transaction = insert(:transaction) |> with_block()

      internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          transaction_index: 0,
          block_number: transaction.block_number,
          index: 1
        )

      transaction_2 = insert(:transaction) |> with_block()

      internal_transactions =
        for i <- 1..50 do
          insert(:internal_transaction,
            transaction: transaction_2,
            transaction_index: 0,
            block_number: transaction_2.block_number,
            index: i
          )
        end

      internal_transactions = InternalTransaction.preload_addresses([internal_transaction | internal_transactions])

      request = get(conn, "/api/v2/internal-transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/internal-transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, internal_transactions)
    end

    test "excludes zero index internal transaction when querying by transaction_hash", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      # Insert internal transaction with index 0 (origin sender transaction) - should be excluded
      insert(:internal_transaction,
        transaction: tx,
        transaction_index: 0,
        block_number: tx.block_number,
        index: 0,
        type: :call
      )

      # Insert internal transaction with index 1 - should be included
      _it_1 =
        insert(:internal_transaction,
          transaction: tx,
          transaction_index: 0,
          block_number: tx.block_number,
          index: 1,
          type: :call
        )

      # Insert internal transaction with index 2 - should be included
      _it_2 =
        insert(:internal_transaction,
          transaction: tx,
          transaction_index: 0,
          block_number: tx.block_number,
          index: 2,
          type: :call
        )

      request = get(conn, "/api/v2/internal-transactions", %{"transaction_hash" => to_string(tx.hash)})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil

      # Verify that only index 1 and 2 are returned, not index 0
      returned_indices = Enum.map(response["items"], & &1["index"])
      assert 1 in returned_indices
      assert 2 in returned_indices
      refute 0 in returned_indices
    end

    test "pagination works correctly with zero index filtering", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      # Insert internal transaction with index 0 - should be excluded
      insert(:internal_transaction,
        transaction: tx,
        transaction_index: 0,
        block_number: tx.block_number,
        index: 0,
        type: :call
      )

      # Insert 51 internal transactions with index 1-51
      for i <- 1..51 do
        insert(:internal_transaction,
          transaction: tx,
          transaction_index: 0,
          block_number: tx.block_number,
          index: i,
          type: :call
        )
      end

      request = get(conn, "/api/v2/internal-transactions", %{"transaction_hash" => to_string(tx.hash)})
      assert response = json_response(request, 200)

      # Should return 50 items (excluding index 0)
      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil

      # First item should be index 1, not 0
      assert List.first(response["items"])["index"] == 1

      # Get second page
      request_2nd_page = get(conn, "/api/v2/internal-transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      # Second page should have 1 item
      assert Enum.count(response_2nd_page["items"]) == 1
      assert response_2nd_page["next_page_params"] == nil
    end

    test "include_zero_value=false excludes zero-value call internal transactions", %{conn: conn} do
      tx =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: tx,
        transaction_index: tx.index,
        block_number: tx.block_number,
        index: 1,
        type: :call,
        value: Decimal.new(0)
      )

      insert(:internal_transaction,
        transaction: tx,
        transaction_index: tx.index,
        block_number: tx.block_number,
        index: 2,
        type: :call,
        value: Decimal.new(1)
      )

      request = get(conn, "/api/v2/internal-transactions", %{"include_zero_value" => "false"})
      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert List.first(response["items"])["index"] == 2

      request_default = get(conn, "/api/v2/internal-transactions")
      assert response_default = json_response(request_default, 200)
      assert Enum.count(response_default["items"]) == 2
    end
  end

  # `EthereumJSONRPC.RSK` and `EthereumJSONRPC.Filecoin` variants trace blocks with `trace_block`
  if Application.compile_env(:explorer, :chain_type) not in [:rsk, :filecoin] do
    describe "/internal-transactions fetched from the node" do
      setup :set_mox_global
      setup :verify_on_exit!

      setup do
        initial_index_finished? =
          BackgroundMigrations.get_heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished()

        BackgroundMigrations.set_heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished(
          true
        )

        initial_geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)

        Application.put_env(
          :ethereum_jsonrpc,
          EthereumJSONRPC.Geth,
          Keyword.merge(initial_geth_config || [], tracer: "call_tracer", block_traceable?: true)
        )

        on_exit(fn ->
          BackgroundMigrations.set_heavy_indexes_create_internal_transactions_block_number_desc_transaction_index_desc_index_desc_index_finished(
            initial_index_finished?
          )

          Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, initial_geth_config)
        end)
      end

      test "goes on with the block that fails to be traced on the next page when the storage is disabled", %{
        conn: conn
      } do
        put_explorer_config(InternalTransaction, storage_disabled?: true)

        for block_number <- 0..3 do
          insert(:block, number: block_number)
        end

        expect(EthereumJSONRPC.Mox, :json_rpc, 2, fn [%{id: id, params: [block_quantity, _]}], _ ->
          case block_quantity do
            "0x3" -> {:ok, [%{id: id, result: block_traces_with_value_call(3)}]}
            "0x2" -> {:ok, [%{id: id, error: %{code: -32_000, message: "tracing failed"}}]}
          end
        end)

        request = get(conn, "/api/v2/internal-transactions")

        assert %{"items" => [%{"block_number" => 3}], "next_page_params" => next_page_params} =
                 json_response(request, 200)

        assert %{"block_number" => 3, "transaction_index" => 0, "index" => 0} = next_page_params

        # block 2 is traced again on the next page, followed by the older blocks
        expect(EthereumJSONRPC.Mox, :json_rpc, 4, fn [%{id: id, params: [block_quantity, _]}], _ ->
          case EthereumJSONRPC.quantity_to_integer(block_quantity) do
            0 -> {:ok, [%{id: id, result: []}]}
            block_number -> {:ok, [%{id: id, result: block_traces_with_value_call(block_number)}]}
          end
        end)

        request = get(conn, "/api/v2/internal-transactions", next_page_params)

        assert %{"items" => [%{"block_number" => 2}, %{"block_number" => 1}], "next_page_params" => nil} =
                 json_response(request, 200)
      end

      test "leaves the DB items of the blocks not traced by the node for the next page", %{conn: conn} do
        # zero-value calls of all the blocks are deleted
        put_explorer_config(Explorer.Migrator.DeleteZeroValueInternalTransactions, enabled: true, storage_period: 0)

        blocks =
          for block_number <- 0..3, into: %{} do
            {block_number, insert(:block, number: block_number, timestamp: Timex.shift(Timex.now(), days: -1))}
          end

        for block_number <- [3, 1] do
          transaction = :transaction |> insert() |> with_block(blocks[block_number])

          insert(:internal_transaction,
            transaction: transaction,
            transaction_index: transaction.index,
            index: 2,
            value: 1,
            block_number: block_number
          )
        end

        %{address_id: address_id} = insert(:address_id_to_address_hash, address: insert(:address))
        insert(:deleted_internal_transactions_address_placeholder, address_id: address_id, block_number: 2)

        expect(EthereumJSONRPC.Mox, :json_rpc, 2, fn [%{id: id, params: [block_quantity, _]}], _ ->
          case block_quantity do
            "0x3" -> {:ok, [%{id: id, result: block_traces_with_value_call(3)}]}
            "0x2" -> {:ok, [%{id: id, error: %{code: -32_000, message: "tracing failed"}}]}
          end
        end)

        request = get(conn, "/api/v2/internal-transactions")

        # the DB item of block 1 waits for the node to trace block 2
        assert %{"items" => [_ | _] = items, "next_page_params" => %{"block_number" => 3}} =
                 json_response(request, 200)

        assert Enum.all?(items, &(&1["block_number"] == 3))
      end
    end
  end

  defp put_explorer_config(module, config) do
    initial_config = Application.get_env(:explorer, module)
    Application.put_env(:explorer, module, Keyword.merge(initial_config || [], config))

    on_exit(fn ->
      if is_nil(initial_config) do
        Application.delete_env(:explorer, module)
      else
        Application.put_env(:explorer, module, initial_config)
      end
    end)
  end

  # `debug_traceBlockByNumber` result with a transaction that transfers value in a nested call
  defp block_traces_with_value_call(block_number) do
    [
      %{
        "result" => %{
          "calls" => [
            %{
              "from" => "0x4200000000000000000000000000000000000015",
              "gas" => "0xe9a3c",
              "gasUsed" => "0x4a28",
              "input" => "0x",
              "output" => "0x",
              "to" => "0x4200000000000000000000000000000000000016",
              "type" => "CALL",
              "value" => "0x1"
            }
          ],
          "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
          "gas" => "0xf4240",
          "gasUsed" => "0xb6f9",
          "input" => "0x",
          "output" => "0x",
          "to" => "0x4200000000000000000000000000000000000015",
          "type" => "CALL",
          "value" => "0x0"
        },
        "txHash" => "0x" <> String.pad_leading("#{block_number}", 64, "0")
      }
    ]
  end

  defp pending_head_tolerance do
    Application.get_env(:explorer, PendingOperationsHelper)[:internal_transactions_pending_head_tolerance]
  end

  defp compare_item(%InternalTransaction{} = internal_transaction, json) do
    assert Address.checksum(internal_transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(internal_transaction.to_address_hash) == json["to"]["hash"]
    assert to_string(internal_transaction.transaction.hash) == json["transaction_hash"]
    assert internal_transaction.block_number == json["block_number"]
    assert internal_transaction.transaction_index == json["transaction_index"]
    assert internal_transaction.index == json["index"]
  end

  defp check_paginated_response(first_page_resp, second_page_resp, internal_transactions) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(internal_transactions, 50), Enum.at(first_page_resp["items"], 0))

    compare_item(Enum.at(internal_transactions, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(internal_transactions, 0), Enum.at(second_page_resp["items"], 0))
  end
end
