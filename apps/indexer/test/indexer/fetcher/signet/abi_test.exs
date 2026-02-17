defmodule Indexer.Fetcher.Signet.AbiTest do
  @moduledoc """
  Unit tests for Indexer.Fetcher.Signet.Abi module.
  
  Tests verify event topic hash computation and ABI loading functionality.
  """

  use ExUnit.Case, async: true

  alias Indexer.Fetcher.Signet.Abi

  describe "event topic hashes" do
    test "order_event_topic/0 returns valid keccak256 hash" do
      topic = Abi.order_event_topic()
      
      # Should be a hex string starting with 0x and 64 hex chars (32 bytes)
      assert String.starts_with?(topic, "0x")
      assert String.length(topic) == 66
      
      # Verify it's a valid hex string
      "0x" <> hex = topic
      assert {:ok, _} = Base.decode16(hex, case: :lower)
    end

    test "filled_event_topic/0 returns valid keccak256 hash" do
      topic = Abi.filled_event_topic()
      
      assert String.starts_with?(topic, "0x")
      assert String.length(topic) == 66
      
      "0x" <> hex = topic
      assert {:ok, _} = Base.decode16(hex, case: :lower)
    end

    test "sweep_event_topic/0 returns valid keccak256 hash" do
      topic = Abi.sweep_event_topic()
      
      assert String.starts_with?(topic, "0x")
      assert String.length(topic) == 66
      
      "0x" <> hex = topic
      assert {:ok, _} = Base.decode16(hex, case: :lower)
    end

    test "event topics are different from each other" do
      order_topic = Abi.order_event_topic()
      filled_topic = Abi.filled_event_topic()
      sweep_topic = Abi.sweep_event_topic()
      
      refute order_topic == filled_topic
      refute order_topic == sweep_topic
      refute filled_topic == sweep_topic
    end

    test "event topics are consistent (deterministic)" do
      # Topics should be the same on repeated calls
      topic1 = Abi.order_event_topic()
      topic2 = Abi.order_event_topic()
      assert topic1 == topic2
    end
  end

  describe "event signatures" do
    test "order_event_signature/0 returns expected format" do
      sig = Abi.order_event_signature()
      
      # Should follow format: Order(uint256,(address,uint256)[],(address,uint256,address,uint32)[])
      assert String.starts_with?(sig, "Order(")
      assert String.contains?(sig, "uint256")
      assert String.contains?(sig, "address")
    end

    test "filled_event_signature/0 returns expected format" do
      sig = Abi.filled_event_signature()
      
      # Should follow format: Filled((address,uint256,address,uint32)[])
      assert String.starts_with?(sig, "Filled(")
      assert String.contains?(sig, "uint32")
    end

    test "sweep_event_signature/0 returns expected format" do
      sig = Abi.sweep_event_signature()
      
      # Should follow format: Sweep(address,address,uint256)
      assert String.starts_with?(sig, "Sweep(")
      assert String.contains?(sig, "address")
    end
  end

  describe "rollup_orders_event_topics/0" do
    test "returns list of three topics" do
      topics = Abi.rollup_orders_event_topics()
      
      assert is_list(topics)
      assert length(topics) == 3
    end

    test "includes all rollup event topics" do
      topics = Abi.rollup_orders_event_topics()
      
      assert Abi.order_event_topic() in topics
      assert Abi.filled_event_topic() in topics
      assert Abi.sweep_event_topic() in topics
    end
  end

  describe "host_orders_event_topics/0" do
    test "returns list with only filled topic" do
      topics = Abi.host_orders_event_topics()
      
      assert is_list(topics)
      assert length(topics) == 1
      assert Abi.filled_event_topic() in topics
    end
  end

  describe "abi_path/1" do
    test "returns path for rollup_orders contract" do
      path = Abi.abi_path("rollup_orders")
      
      assert String.contains?(path, "priv/contracts_abi/signet/rollup_orders.json")
    end

    test "returns path for host_orders contract" do
      path = Abi.abi_path("host_orders")
      
      assert String.contains?(path, "priv/contracts_abi/signet/host_orders.json")
    end
  end

  describe "load_abi/1" do
    test "loads rollup_orders ABI successfully" do
      result = Abi.load_abi("rollup_orders")
      
      assert {:ok, abi} = result
      assert is_list(abi)
      assert length(abi) > 0
    end

    test "loads host_orders ABI successfully" do
      result = Abi.load_abi("host_orders")
      
      assert {:ok, abi} = result
      assert is_list(abi)
      assert length(abi) > 0
    end

    test "returns error for nonexistent contract" do
      result = Abi.load_abi("nonexistent_contract")
      
      assert {:error, :not_found} = result
    end
  end
end
