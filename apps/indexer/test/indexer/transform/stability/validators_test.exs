if Application.compile_env(:explorer, :chain_type) == :stability do
  defmodule Indexer.Transform.Stability.ValidatorsTest do
    use ExUnit.Case, async: true

    alias Indexer.Transform.Stability.Validators

    describe "parse/1" do
      setup do
        # Save original chain type and restore after each test
        original_chain_type = Application.get_env(:explorer, :chain_type)

        on_exit(fn ->
          Application.put_env(:explorer, :chain_type, original_chain_type)
        end)

        :ok
      end

      test "parses blocks for stability chain type and returns validator counter updates" do
        Application.put_env(:explorer, :chain_type, :stability)

        blocks = [
          %{
            number: 100,
            hash: "0xabc123",
            miner_hash: "0x1234567890abcdef1234567890abcdef12345678"
          },
          %{
            number: 101,
            hash: "0xdef456",
            miner_hash: "0x1234567890abcdef1234567890abcdef12345678"
          },
          %{
            number: 102,
            hash: "0x789012",
            miner_hash: "0xabcdef1234567890abcdef1234567890abcdef12"
          }
        ]

        result = Validators.parse(blocks)

        expected = [
          %{
            address_hash: "0x1234567890abcdef1234567890abcdef12345678",
            blocks_validated: 2
          },
          %{
            address_hash: "0xabcdef1234567890abcdef1234567890abcdef12",
            blocks_validated: 1
          }
        ]

        # Sort both lists by address_hash for comparison
        sorted_result = Enum.sort_by(result, & &1.address_hash)
        sorted_expected = Enum.sort_by(expected, & &1.address_hash)

        assert sorted_result == sorted_expected
      end

      test "filters out blocks with nil miner_hash" do
        Application.put_env(:explorer, :chain_type, :stability)

        blocks = [
          %{
            number: 100,
            hash: "0xabc123",
            miner_hash: "0x1234567890abcdef1234567890abcdef12345678"
          },
          %{
            number: 101,
            hash: "0xdef456",
            miner_hash: nil
          },
          %{
            number: 102,
            hash: "0x789012"
            # no miner_hash field
          }
        ]

        result = Validators.parse(blocks)

        expected = [
          %{
            address_hash: "0x1234567890abcdef1234567890abcdef12345678",
            blocks_validated: 1
          }
        ]

        assert result == expected
      end

      test "returns empty list for non-stability chain type" do
        Application.put_env(:explorer, :chain_type, :ethereum)

        blocks = [
          %{
            number: 100,
            hash: "0xabc123",
            miner_hash: "0x1234567890abcdef1234567890abcdef12345678"
          },
          %{
            number: 101,
            hash: "0xdef456",
            miner_hash: "0xabcdef1234567890abcdef1234567890abcdef12"
          }
        ]

        result = Validators.parse(blocks)

        assert result == []
      end

      test "returns empty list for empty blocks list" do
        Application.put_env(:explorer, :chain_type, :stability)

        result = Validators.parse([])

        assert result == []
      end

      test "returns empty list for nil input" do
        Application.put_env(:explorer, :chain_type, :stability)

        result = Validators.parse(nil)

        assert result == []
      end

      test "groups multiple blocks by same validator correctly" do
        Application.put_env(:explorer, :chain_type, :stability)

        blocks = [
          %{number: 100, hash: "0x1", miner_hash: "0x1111"},
          %{number: 101, hash: "0x2", miner_hash: "0x1111"},
          %{number: 102, hash: "0x3", miner_hash: "0x1111"},
          %{number: 103, hash: "0x4", miner_hash: "0x2222"},
          %{number: 104, hash: "0x5", miner_hash: "0x1111"}
        ]

        result = Validators.parse(blocks)

        expected = [
          %{
            address_hash: "0x1111",
            blocks_validated: 4
          },
          %{
            address_hash: "0x2222",
            blocks_validated: 1
          }
        ]

        # Sort both lists by address_hash for comparison
        sorted_result = Enum.sort_by(result, & &1.address_hash)
        sorted_expected = Enum.sort_by(expected, & &1.address_hash)

        assert sorted_result == sorted_expected
      end
    end
  end
end
