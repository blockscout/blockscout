defmodule Indexer.Fetcher.Signet.OrdersFetcherTest do
  @moduledoc """
  Integration tests for the Signet OrdersFetcher module.

  These tests verify the full pipeline from event fetching through
  database insertion, including reorg handling and database utilities.

  Note: Orders and fills are indexed independently with no correlation.
  Primary keys are:
    - Orders: (transaction_hash, log_index)
    - Fills: (chain_type, transaction_hash, log_index)
  """

  use Explorer.DataCase, async: false

  import Explorer.Factory

  alias Explorer.Chain
  alias Explorer.Chain.Signet.{Order, Fill}
  alias Explorer.Repo
  alias Indexer.Fetcher.Signet.{OrdersFetcher, ReorgHandler}
  alias Indexer.Fetcher.Signet.Utils.Db

  @moduletag :signet

  describe "OrdersFetcher configuration" do
    test "child_spec returns proper supervisor config" do
      json_rpc_named_arguments = [
        transport: EthereumJSONRPC.Mox,
        transport_options: []
      ]

      Application.put_env(:indexer, OrdersFetcher,
        enabled: true,
        rollup_orders_address: "0x1234567890123456789012345678901234567890",
        recheck_interval: 1000
      )

      child_spec = OrdersFetcher.child_spec([
        [json_rpc_named_arguments: json_rpc_named_arguments],
        [name: OrdersFetcher]
      ])

      assert child_spec.id == OrdersFetcher
      assert child_spec.restart == :transient
    end
  end

  describe "database import via Chain.import/1" do
    test "imports order through Chain.import" do
      tx_hash = <<1::256>>

      order_params = %{
        deadline: 1_700_000_000,
        block_number: 100,
        transaction_hash: tx_hash,
        log_index: 0,
        inputs_json: Jason.encode!([%{"token" => "0x1234", "amount" => "1000"}]),
        outputs_json: Jason.encode!([%{"token" => "0x5678", "recipient" => "0x9abc", "amount" => "500", "chainId" => "1"}])
      }

      assert {:ok, %{insert_signet_orders: [order]}} =
               Chain.import(%{
                 signet_orders: %{params: [order_params]},
                 timeout: :infinity
               })

      assert order.block_number == 100
      assert order.deadline == 1_700_000_000
    end

    test "imports fill through Chain.import" do
      tx_hash = <<2::256>>

      fill_params = %{
        chain_type: :rollup,
        block_number: 150,
        transaction_hash: tx_hash,
        log_index: 1,
        outputs_json: Jason.encode!([%{"token" => "0xaaaa", "recipient" => "0xbbbb", "amount" => "1000", "chainId" => "1"}])
      }

      assert {:ok, %{insert_signet_fills: [fill]}} =
               Chain.import(%{
                 signet_fills: %{params: [fill_params]},
                 timeout: :infinity
               })

      assert fill.block_number == 150
      assert fill.chain_type == :rollup
    end

    test "imports order and fill together" do
      order_params = %{
        deadline: 1_700_000_000,
        block_number: 100,
        transaction_hash: <<10::256>>,
        log_index: 0,
        inputs_json: Jason.encode!([%{"token" => "0x1111", "amount" => "1000"}]),
        outputs_json: Jason.encode!([%{"token" => "0x2222", "recipient" => "0x3333", "amount" => "500", "chainId" => "1"}])
      }

      fill_params = %{
        chain_type: :host,
        block_number: 200,
        transaction_hash: <<20::256>>,
        log_index: 0,
        outputs_json: Jason.encode!([%{"token" => "0x2222", "recipient" => "0x3333", "amount" => "500", "chainId" => "1"}])
      }

      assert {:ok, result} =
               Chain.import(%{
                 signet_orders: %{params: [order_params]},
                 signet_fills: %{params: [fill_params]},
                 timeout: :infinity
               })

      assert length(result.insert_signet_orders) == 1
      assert length(result.insert_signet_fills) == 1
    end
  end

  describe "ReorgHandler" do
    test "rollup reorg removes orders and rollup fills from affected blocks" do
      # Insert test data
      insert_test_order(<<1::256>>, 100)
      insert_test_order(<<2::256>>, 200)
      insert_test_order(<<3::256>>, 300)

      insert_test_fill(:rollup, <<11::256>>, 150)
      insert_test_fill(:rollup, <<12::256>>, 250)
      insert_test_fill(:host, <<13::256>>, 250)  # Host fill should survive rollup reorg

      assert Repo.aggregate(Order, :count) == 3
      assert Repo.aggregate(Fill, :count) == 3

      # Trigger reorg from block 200
      ReorgHandler.handle_reorg(200, :rollup)

      # Orders from block 200+ should be deleted
      assert Repo.aggregate(Order, :count) == 1
      remaining_order = Repo.one(Order)
      assert remaining_order.block_number == 100

      # Rollup fills from block 200+ should be deleted
      fills = Repo.all(Fill)
      assert length(fills) == 2
      rollup_fills = Enum.filter(fills, &(&1.chain_type == :rollup))
      host_fills = Enum.filter(fills, &(&1.chain_type == :host))
      assert length(rollup_fills) == 1
      assert hd(rollup_fills).block_number == 150
      # Host fill should remain
      assert length(host_fills) == 1
    end

    test "host reorg only removes host fills from affected blocks" do
      # Insert test data
      insert_test_order(<<1::256>>, 100)
      insert_test_fill(:rollup, <<11::256>>, 150)
      insert_test_fill(:host, <<21::256>>, 200)
      insert_test_fill(:host, <<22::256>>, 300)

      # Trigger host reorg from block 250
      ReorgHandler.handle_reorg(250, :host)

      # Order should remain
      assert Repo.aggregate(Order, :count) == 1

      # Rollup fill should remain
      fills = Repo.all(Fill)
      rollup_fills = Enum.filter(fills, &(&1.chain_type == :rollup))
      host_fills = Enum.filter(fills, &(&1.chain_type == :host))

      assert length(rollup_fills) == 1
      assert length(host_fills) == 1  # Only host fill at block 200 remains
      assert hd(host_fills).block_number == 200
    end

    test "reorg at genesis deletes all data" do
      insert_test_order(<<1::256>>, 100)
      insert_test_order(<<2::256>>, 200)
      insert_test_fill(:rollup, <<11::256>>, 150)
      insert_test_fill(:host, <<21::256>>, 250)

      ReorgHandler.handle_reorg(0, :rollup)

      assert Repo.aggregate(Order, :count) == 0
      rollup_fills = Repo.all(from(f in Fill, where: f.chain_type == :rollup))
      assert length(rollup_fills) == 0
      # Host fill should remain even in rollup reorg
      host_fills = Repo.all(from(f in Fill, where: f.chain_type == :host))
      assert length(host_fills) == 1
    end
  end

  describe "Db utility functions" do
    test "highest_indexed_order_block returns correct value" do
      assert Db.highest_indexed_order_block(0) == 0

      insert_test_order(<<1::256>>, 100)
      insert_test_order(<<2::256>>, 200)
      insert_test_order(<<3::256>>, 150)

      assert Db.highest_indexed_order_block(0) == 200
    end

    test "highest_indexed_fill_block returns correct value per chain" do
      assert Db.highest_indexed_fill_block(:rollup, 0) == 0
      assert Db.highest_indexed_fill_block(:host, 0) == 0

      insert_test_fill(:rollup, <<11::256>>, 100)
      insert_test_fill(:rollup, <<12::256>>, 200)
      insert_test_fill(:host, <<21::256>>, 150)
      insert_test_fill(:host, <<22::256>>, 300)

      assert Db.highest_indexed_fill_block(:rollup, 0) == 200
      assert Db.highest_indexed_fill_block(:host, 0) == 300
    end

    test "get_orders_by_deadline_range returns orders in range" do
      insert_test_order_with_deadline(<<1::256>>, 100, 1_000)
      insert_test_order_with_deadline(<<2::256>>, 200, 2_000)
      insert_test_order_with_deadline(<<3::256>>, 300, 3_000)

      orders = Db.get_orders_by_deadline_range(1_500, 2_500)
      assert length(orders) == 1
      assert hd(orders).deadline == 2_000
    end

    test "get_order_fill_counts returns accurate counts" do
      insert_test_order(<<1::256>>, 100)
      insert_test_order(<<2::256>>, 200)
      insert_test_fill(:rollup, <<11::256>>, 150)
      insert_test_fill(:rollup, <<12::256>>, 250)
      insert_test_fill(:host, <<21::256>>, 300)

      counts = Db.get_order_fill_counts()

      assert counts.orders == 2
      assert counts.rollup_fills == 2
      assert counts.host_fills == 1
    end
  end

  describe "factory integration" do
    test "signet_order factory creates valid order" do
      order = insert(:signet_order)

      assert order.transaction_hash != nil
      assert order.log_index != nil
      assert order.deadline != nil
      assert order.block_number != nil
      assert order.inputs_json != nil
      assert order.outputs_json != nil
    end

    test "signet_fill factory creates valid fill" do
      fill = insert(:signet_fill)

      assert fill.transaction_hash != nil
      assert fill.log_index != nil
      assert fill.chain_type in [:rollup, :host]
      assert fill.block_number != nil
      assert fill.outputs_json != nil
    end

    test "factory orders can be customized" do
      order = insert(:signet_order, deadline: 9999999999, block_number: 42)

      assert order.deadline == 9999999999
      assert order.block_number == 42
    end

    test "factory fills can be customized" do
      fill = insert(:signet_fill, chain_type: :host, block_number: 123)

      assert fill.chain_type == :host
      assert fill.block_number == 123
    end
  end

  # Helper functions for test data insertion

  defp insert_test_order(tx_hash, block_number) do
    params = %{
      deadline: 1_700_000_000,
      block_number: block_number,
      transaction_hash: tx_hash,
      log_index: 0,
      inputs_json: Jason.encode!([%{"token" => "0xabc", "amount" => "1000"}]),
      outputs_json: Jason.encode!([%{"token" => "0xdef", "recipient" => "0x123", "amount" => "500", "chainId" => "1"}])
    }

    {:ok, %{insert_signet_orders: [order]}} =
      Chain.import(%{signet_orders: %{params: [params]}, timeout: :infinity})

    order
  end

  defp insert_test_order_with_deadline(tx_hash, block_number, deadline) do
    params = %{
      deadline: deadline,
      block_number: block_number,
      transaction_hash: tx_hash,
      log_index: 0,
      inputs_json: Jason.encode!([%{"token" => "0xabc", "amount" => "1000"}]),
      outputs_json: Jason.encode!([%{"token" => "0xdef", "recipient" => "0x123", "amount" => "500", "chainId" => "1"}])
    }

    {:ok, %{insert_signet_orders: [order]}} =
      Chain.import(%{signet_orders: %{params: [params]}, timeout: :infinity})

    order
  end

  defp insert_test_fill(chain_type, tx_hash, block_number) do
    params = %{
      chain_type: chain_type,
      block_number: block_number,
      transaction_hash: tx_hash,
      log_index: 0,
      outputs_json: Jason.encode!([%{"token" => "0xfff", "recipient" => "0x999", "amount" => "500", "chainId" => "1"}])
    }

    {:ok, %{insert_signet_fills: [fill]}} =
      Chain.import(%{signet_fills: %{params: [params]}, timeout: :infinity})

    fill
  end
end
