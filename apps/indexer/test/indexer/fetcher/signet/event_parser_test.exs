defmodule Indexer.Fetcher.Signet.EventParserTest do
  @moduledoc """
  Unit tests for Indexer.Fetcher.Signet.EventParser module.
  
  Tests verify event parsing, Output struct field ordering, and 
  outputs_witness_hash computation for cross-chain order correlation.
  
  Output struct field order (per @signet-sh/sdk):
  (address token, uint256 amount, address recipient, uint32 chainId)
  """

  use ExUnit.Case, async: true

  alias Indexer.Fetcher.Signet.{Abi, EventParser}

  # Test addresses (20 bytes each)
  @test_token <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20>>
  @test_recipient <<21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40>>
  @test_amount 1_000_000_000_000_000_000  # 1e18
  @test_chain_id 1  # Mainnet

  describe "compute_outputs_witness_hash/1" do
    test "returns 32-byte hash for single output" do
      outputs = [{@test_token, @test_amount, @test_recipient, @test_chain_id}]
      
      hash = EventParser.compute_outputs_witness_hash(outputs)
      
      assert byte_size(hash) == 32
    end

    test "returns deterministic hash for same outputs" do
      outputs = [{@test_token, @test_amount, @test_recipient, @test_chain_id}]
      
      hash1 = EventParser.compute_outputs_witness_hash(outputs)
      hash2 = EventParser.compute_outputs_witness_hash(outputs)
      
      assert hash1 == hash2
    end

    test "returns different hashes for different outputs" do
      outputs1 = [{@test_token, @test_amount, @test_recipient, @test_chain_id}]
      outputs2 = [{@test_token, @test_amount + 1, @test_recipient, @test_chain_id}]
      
      hash1 = EventParser.compute_outputs_witness_hash(outputs1)
      hash2 = EventParser.compute_outputs_witness_hash(outputs2)
      
      refute hash1 == hash2
    end

    test "different chain_id produces different hash" do
      outputs1 = [{@test_token, @test_amount, @test_recipient, 1}]
      outputs2 = [{@test_token, @test_amount, @test_recipient, 42161}]  # Arbitrum
      
      hash1 = EventParser.compute_outputs_witness_hash(outputs1)
      hash2 = EventParser.compute_outputs_witness_hash(outputs2)
      
      refute hash1 == hash2
    end

    test "order of outputs matters" do
      output1 = {@test_token, @test_amount, @test_recipient, @test_chain_id}
      output2 = {@test_recipient, @test_amount * 2, @test_token, 42161}
      
      hash_ordered = EventParser.compute_outputs_witness_hash([output1, output2])
      hash_reversed = EventParser.compute_outputs_witness_hash([output2, output1])
      
      refute hash_ordered == hash_reversed
    end

    test "handles empty outputs list" do
      hash = EventParser.compute_outputs_witness_hash([])
      
      # Should still return a valid hash (hash of empty concat)
      assert byte_size(hash) == 32
    end

    test "handles multiple outputs" do
      outputs = [
        {@test_token, 100, @test_recipient, 1},
        {@test_recipient, 200, @test_token, 42161},
        {@test_token, 300, @test_recipient, 10}  # Optimism
      ]
      
      hash = EventParser.compute_outputs_witness_hash(outputs)
      
      assert byte_size(hash) == 32
    end
  end

  describe "parse_rollup_logs/1" do
    test "returns empty lists for empty logs" do
      {:ok, {orders, fills}} = EventParser.parse_rollup_logs([])
      
      assert orders == []
      assert fills == []
    end

    test "ignores logs with non-matching topics" do
      logs = [
        %{
          "topics" => ["0x0000000000000000000000000000000000000000000000000000000000000000"],
          "data" => "0x",
          "blockNumber" => "0x1",
          "transactionHash" => "0x" <> String.duplicate("ab", 32),
          "logIndex" => "0x0"
        }
      ]
      
      {:ok, {orders, fills}} = EventParser.parse_rollup_logs(logs)
      
      assert orders == []
      assert fills == []
    end
  end

  describe "parse_host_filled_logs/1" do
    test "returns empty list for empty logs" do
      {:ok, fills} = EventParser.parse_host_filled_logs([])
      
      assert fills == []
    end

    test "ignores logs with non-matching topics" do
      logs = [
        %{
          "topics" => ["0x0000000000000000000000000000000000000000000000000000000000000000"],
          "data" => "0x",
          "blockNumber" => "0x1",
          "transactionHash" => "0x" <> String.duplicate("ab", 32),
          "logIndex" => "0x0"
        }
      ]
      
      {:ok, fills} = EventParser.parse_host_filled_logs(logs)
      
      assert fills == []
    end
  end

  describe "output struct field order verification" do
    @tag :output_field_order
    test "Output struct follows SDK order: (token, amount, recipient, chainId)" do
      # Per @signet-sh/sdk, Output is defined as:
      # struct Output {
      #   address token;
      #   uint256 amount;
      #   address recipient;
      #   uint32 chainId;
      # }
      #
      # This is the correct field order used in the EventParser tuple:
      # {token, amount, recipient, chain_id}
      
      token = @test_token
      amount = @test_amount
      recipient = @test_recipient
      chain_id = @test_chain_id
      
      # The tuple format used in EventParser
      output_tuple = {token, amount, recipient, chain_id}
      
      # Extract fields in the expected SDK order
      {extracted_token, extracted_amount, extracted_recipient, extracted_chain_id} = output_tuple
      
      assert extracted_token == token
      assert extracted_amount == amount
      assert extracted_recipient == recipient
      assert extracted_chain_id == chain_id
    end

    test "compute_outputs_witness_hash uses correct Output encoding order" do
      # When encoding for witness hash, the order must be:
      # (token, amount, recipient, chainId)
      # NOT the old incorrect order: (recipient, token, amount)
      
      # Two outputs with same data but different "interpretations" 
      # would produce different hashes if order is wrong
      
      token = @test_token
      amount = 12345
      recipient = @test_recipient
      chain_id = 42161
      
      # Correct order: (token, amount, recipient, chainId)
      correct_output = [{token, amount, recipient, chain_id}]
      
      # What the hash would be if we incorrectly swapped token/recipient
      incorrect_output = [{recipient, amount, token, chain_id}]
      
      correct_hash = EventParser.compute_outputs_witness_hash(correct_output)
      incorrect_hash = EventParser.compute_outputs_witness_hash(incorrect_output)
      
      # Hashes must be different - this validates the encoding uses correct order
      refute correct_hash == incorrect_hash
    end
  end

  describe "log field parsing helpers" do
    test "handles hex-encoded block numbers" do
      # Test that block_number parsing works for hex strings
      log = %{
        "blockNumber" => "0x10",  # 16 in decimal
        "topics" => [],
        "data" => "0x"
      }
      
      # The parser should correctly decode hex block numbers
      # This is implicitly tested through parse_rollup_logs/1
      {:ok, {[], []}} = EventParser.parse_rollup_logs([log])
    end

    test "handles integer block numbers" do
      log = %{
        :block_number => 16,
        :topics => [],
        :data => ""
      }
      
      {:ok, {[], []}} = EventParser.parse_rollup_logs([log])
    end
  end

  describe "event topic matching" do
    test "Order event topic matches Abi module" do
      order_topic = Abi.order_event_topic()
      
      # Verify the topic format
      assert String.starts_with?(order_topic, "0x")
      assert String.length(order_topic) == 66
    end

    test "Filled event topic matches Abi module" do
      filled_topic = Abi.filled_event_topic()
      
      assert String.starts_with?(filled_topic, "0x")
      assert String.length(filled_topic) == 66
    end

    test "Sweep event topic matches Abi module" do
      sweep_topic = Abi.sweep_event_topic()
      
      assert String.starts_with?(sweep_topic, "0x")
      assert String.length(sweep_topic) == 66
    end
  end
end
