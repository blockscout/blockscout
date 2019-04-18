defmodule Indexer.Transform.ValidatorsTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Indexer.Transform.Validators

  describe "parse/1" do
    test "parse/1 parses logs for validators" do
      logs = [
        %{
          address_hash: "0x1000000000000000000000000000000000000001",
          block_number: 161,
          data:
            "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000bbcaa8d48289bb1ffcf9808d9aa4b1d215054c7800000000000000000000000075df42383afe6bf5194aa8fa0e9b3d5f9e869441000000000000000000000000522df396ae70a058bd69778408630fdb023389b2",
          first_topic: "0x55252fa6eee4741b4e24a74a70e9c11fd2c2281df8d6ea13126ff845f7825c89",
          fourth_topic: nil,
          index: 0,
          second_topic: "0x09b2f94f1d299df851c5b3465af76e14361cabfbfe03d7a7bb20e2177cb35e7a",
          third_topic: nil,
          transaction_hash: "0xf6f128dcac05777e0f045e81e798b4a3650f591e98ed902fd1649e8758bcf345",
          type: "mined"
        }
      ]

      expected = [
        %{
          address_hash:
            <<187, 202, 168, 212, 130, 137, 187, 31, 252, 249, 128, 141, 154, 164, 177, 210, 21, 5, 76, 120>>,
          name: "anonymous",
          primary: true,
          metadata: %{
            active: true,
            type: "validator"
          }
        },
        %{
          address_hash: <<117, 223, 66, 56, 58, 254, 107, 245, 25, 74, 168, 250, 14, 155, 61, 95, 158, 134, 148, 65>>,
          name: "anonymous",
          primary: true,
          metadata: %{
            active: true,
            type: "validator"
          }
        },
        %{
          address_hash: <<82, 45, 243, 150, 174, 112, 160, 88, 189, 105, 119, 132, 8, 99, 15, 219, 2, 51, 137, 178>>,
          name: "anonymous",
          primary: true,
          metadata: %{
            active: true,
            type: "validator"
          }
        }
      ]

      assert Validators.parse(logs) == expected
    end
  end
end
