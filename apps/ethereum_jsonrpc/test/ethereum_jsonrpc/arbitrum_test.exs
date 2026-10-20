# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.ArbitrumTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.Arbitrum

  # Raw 20-byte binaries as the ABI decoder returns them for the `address` type.
  @caller_starting_with_0x3078 Base.decode16!("3078727d4c7fb6619873320688dff66af82346b2", case: :lower)
  @caller_starting_with_0x30 Base.decode16!("30aa727d4c7fb6619873320688dff66af82346b2", case: :lower)
  @caller_with_leading_zero_bytes Base.decode16!("0000007d4c7fb6619873320688dff66af82346b2", case: :lower)

  describe "value_to_address/1" do
    test "hex-encodes a raw 20-byte caller whose first bytes are 0x30 0x78 (ASCII \"0x\")" do
      assert Arbitrum.value_to_address(@caller_starting_with_0x3078) ==
               "0x3078727d4c7fb6619873320688dff66af82346b2"
    end

    test "hex-encodes a raw 20-byte caller whose first byte is 0x30 (ASCII \"0\")" do
      assert Arbitrum.value_to_address(@caller_starting_with_0x30) ==
               "0x30aa727d4c7fb6619873320688dff66af82346b2"
    end

    test "keeps leading zero bytes of a raw 20-byte caller" do
      assert Arbitrum.value_to_address(@caller_with_leading_zero_bytes) ==
               "0x0000007d4c7fb6619873320688dff66af82346b2"
    end

    test "extracts the address from a 32-byte 0x-prefixed topic string" do
      topic = "0x" <> String.duplicate("0", 24) <> "3078727d4c7fb6619873320688dff66af82346b2"

      assert Arbitrum.value_to_address(topic) == "0x3078727d4c7fb6619873320688dff66af82346b2"
    end

    test "keeps a 0x-prefixed 40-digit address string as is" do
      assert Arbitrum.value_to_address("0x3078727d4c7fb6619873320688dff66af82346b2") ==
               "0x3078727d4c7fb6619873320688dff66af82346b2"
    end

    test "treats any 20-byte binary as raw bytes, even one that reads as a short 0x string" do
      # "0x" plus 18 hex digits is 20 bytes long, the same size as a raw address.
      # A raw address can legitimately start with the bytes 0x30 0x78 (ASCII "0x"),
      # so the content of a 20-byte binary is never inspected: it is always hex-encoded.
      # Supported 0x-prefixed strings have 40 or 64 digits and are 42 or 66 bytes long.
      short_string = "0x" <> String.duplicate("a", 18)

      assert Arbitrum.value_to_address(short_string) == "0x" <> Base.encode16(short_string, case: :lower)
    end

    test "raises for a binary that is neither 20 bytes long nor a 0x-prefixed 40- or 64-digit string" do
      assert_raise FunctionClauseError, fn -> Arbitrum.value_to_address("abc") end
      assert_raise FunctionClauseError, fn -> Arbitrum.value_to_address("0xabc") end
      assert_raise FunctionClauseError, fn -> Arbitrum.value_to_address(<<1::152>>) end
    end
  end

  describe "l2_to_l1_event_parse/1" do
    test "returns a valid caller address when the raw caller starts with 0x3078" do
      destination = "de57d68a1f7bf4b26dc0b6b2e9f84b67e20e8b4f"
      message_id = 8_290_647

      event = build_l2_to_l1_event(@caller_starting_with_0x3078, destination, message_id)

      fields = Arbitrum.l2_to_l1_event_parse(event)

      assert fields.caller == "0x3078727d4c7fb6619873320688dff66af82346b2"
      assert fields.destination == "0x" <> destination
      assert fields.message_id == message_id
      assert fields.arb_block_number == 23_771_343
      assert fields.eth_block_number == 7_500_000
      assert fields.timestamp == 1_752_214_129
      assert fields.callvalue == 1_000
      assert fields.data == <<1, 2, 3>>
    end

    test "returns a valid caller address when the raw caller has leading zero bytes" do
      destination = "de57d68a1f7bf4b26dc0b6b2e9f84b67e20e8b4f"

      event = build_l2_to_l1_event(@caller_with_leading_zero_bytes, destination, 1)

      fields = Arbitrum.l2_to_l1_event_parse(event)

      assert fields.caller == "0x0000007d4c7fb6619873320688dff66af82346b2"
    end
  end

  # Builds an L2ToL1Tx event map in the shape `l2_to_l1_event_parse/1` expects:
  # ABI-encoded unindexed params in `data`, the left-padded destination in
  # `second_topic`, and the message id (position) in `fourth_topic`.
  defp build_l2_to_l1_event(raw_caller, destination_hex, message_id) do
    data_bin =
      ABI.TypeEncoder.encode_raw(
        [raw_caller, 23_771_343, 7_500_000, 1_752_214_129, 1_000, <<1, 2, 3>>],
        [:address, {:uint, 256}, {:uint, 256}, {:uint, 256}, {:uint, 256}, :bytes],
        :standard
      )

    %{
      data: "0x" <> Base.encode16(data_bin, case: :lower),
      second_topic: "0x" <> String.pad_leading(destination_hex, 64, "0"),
      fourth_topic: "0x" <> String.pad_leading(Integer.to_string(message_id, 16), 64, "0")
    }
  end
end
