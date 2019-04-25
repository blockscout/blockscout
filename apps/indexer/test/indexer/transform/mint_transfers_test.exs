defmodule Indexer.Transform.MintTransfersTest do
  use ExUnit.Case, async: true

  alias Indexer.Transform.MintTransfers

  doctest MintTransfers, import: true

  describe "parse/1" do
    test "parses logs for fetch the mint transfer" do
      logs = [
        %{
          address_hash: "0x867305d19606aadba405ce534e303d0e225f9556",
          block_number: 137_194,
          data: "0x0000000000000000000000000000000000000000000000001bc16d674ec80000",
          first_topic: "0x3c798bbcf33115b42c728b8504cff11dd58736e9fa789f1cda2738db7d696b2a",
          fourth_topic: nil,
          index: 1,
          second_topic: "0x0000000000000000000000009a4a90e2732f3fa4087b0bb4bf85c76d14833df1",
          third_topic: "0x0000000000000000000000007301cfa0e1756b71869e93d4e4dca5c7d0eb0aa6",
          transaction_hash: "0x1d5066d30ff3404a9306733136103ac2b0b989951c38df637f464f3667f8d4ee",
          type: "mined"
        }
      ]

      expected = %{
        mint_transfers: [
          %{
            from_address_hash: "0x7301cfa0e1756b71869e93d4e4dca5c7d0eb0aa6",
            to_address_hash: "0x9a4a90e2732f3fa4087b0bb4bf85c76d14833df1",
            block_number: 137_194
          }
        ]
      }

      assert MintTransfers.parse(logs) == expected
    end
  end

  test "returns an empty list when the first topic isn't the brigde hash" do
    logs = [
      %{
        address_hash: "0x867305d19606aadba405ce534e303d0e225f9556",
        block_number: 137_194,
        data: "0x0000000000000000000000000000000000000000000000001bc16d674ec80000",
        first_topic: nil,
        fourth_topic: nil,
        index: 1,
        second_topic: "0x0000000000000000000000009a4a90e2732f3fa4087b0bb4bf85c76d14833df1",
        third_topic: "0x0000000000000000000000007301cfa0e1756b71869e93d4e4dca5c7d0eb0aa6",
        transaction_hash: "0x1d5066d30ff3404a9306733136103ac2b0b989951c38df637f464f3667f8d4ee",
        type: "mined"
      }
    ]

    assert MintTransfers.parse(logs) == %{mint_transfers: []}
  end
end
