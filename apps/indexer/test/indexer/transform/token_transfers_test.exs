defmodule Indexer.Transform.TokenTransfersTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Indexer.Transform.TokenTransfers

  describe "parse/1" do
    test "parse/1 parses logs for tokens and token transfers" do
      [log_1, _log_2, log_3] =
        logs = [
          %{
            address_hash: "0xf2eec76e45b328df99a34fa696320a262cb92154",
            block_number: 3_530_917,
            block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
            data: "0x000000000000000000000000000000000000000000000000ebec21ee1da40000",
            first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            fourth_topic: nil,
            index: 8,
            second_topic: "0x000000000000000000000000556813d9cc20acfe8388af029a679d34a63388db",
            third_topic: "0x00000000000000000000000092148dd870fa1b7c4700f2bd7f44238821c26f73",
            transaction_hash: "0x43dfd761974e8c3351d285ab65bee311454eb45b149a015fe7804a33252f19e5",
            type: "mined"
          },
          %{
            address_hash: "0x6ea5ec9cb832e60b6b1654f5826e9be638f276a5",
            block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
            block_number: 3_586_935,
            data: "0x",
            first_topic: "0x55e10366a5f552746106978b694d7ef3bbddec06bd5f9b9d15ad46f475c653ef",
            fourth_topic: "0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6",
            index: 0,
            second_topic: "0x00000000000000000000000063b0595bb7a0b7edd0549c9557a0c8aee6da667b",
            third_topic: "0x000000000000000000000000f3089e15d0c23c181d7f98b0878b560bfe193a1d",
            transaction_hash: "0x8425a9b81a9bd1c64861110c1a453b84719cb0361d6fa0db68abf7611b9a890e",
            # block_hash: "0x8425a9b81a9bd1c64861110c1a453b84719cb0361d6fa0db68abf7611b9a890e",
            type: "mined"
          },
          %{
            address_hash: "0x91932e8c6776fb2b04abb71874a7988747728bb2",
            block_number: 3_664_064,
            block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
            data: "0x000000000000000000000000000000000000000000000000ebec21ee1da40000",
            first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            fourth_topic: "0x00000000000000000000000000000000000000000000000000000000000000b7",
            index: 1,
            second_topic: "0x0000000000000000000000009851ba177554eb07271ac230a137551e6dd0aa84",
            third_topic: "0x000000000000000000000000dccb72afee70e60b0c1226288fe86c01b953e8ac",
            transaction_hash: "0x4011d9a930a3da620321589a54dc0ca3b88216b4886c7a7c3aaad1fb17702d35",
            # block_hash: "0x4011d9a930a3da620321589a54dc0ca3b88216b4886c7a7c3aaad1fb17702d35",
            type: "mined"
          }
        ]

      expected = %{
        tokens: [
          %{
            contract_address_hash: log_3.address_hash,
            type: "ERC-721"
          },
          %{
            contract_address_hash: log_1.address_hash,
            type: "ERC-20"
          }
        ],
        token_transfers: [
          %{
            block_number: log_3.block_number,
            log_index: log_3.index,
            from_address_hash: truncated_hash(log_3.second_topic),
            to_address_hash: truncated_hash(log_3.third_topic),
            token_contract_address_hash: log_3.address_hash,
            token_ids: [183],
            transaction_hash: log_3.transaction_hash,
            token_type: "ERC-721",
            block_hash: log_3.block_hash
          },
          %{
            token_ids: nil,
            amount: Decimal.new(17_000_000_000_000_000_000),
            block_number: log_1.block_number,
            log_index: log_1.index,
            from_address_hash: truncated_hash(log_1.second_topic),
            to_address_hash: truncated_hash(log_1.third_topic),
            token_contract_address_hash: log_1.address_hash,
            transaction_hash: log_1.transaction_hash,
            token_type: "ERC-20",
            comment: nil,
            block_hash: log_1.block_hash
          }
        ]
      }

      assert TokenTransfers.parse(logs) == expected
    end

    test "parses ERC-721 transfer with addresses in data field" do
      log = %{
        address_hash: "0x58Ab73CB79c8275628E0213742a85B163fE0A9Fb",
        block_number: 8_683_457,
        data:
          "0x00000000000000000000000058ab73cb79c8275628e0213742a85b163fe0a9fb000000000000000000000000be8cdfc13ffda20c844ac3da2b53a23ac5787f1e0000000000000000000000000000000000000000000000000000000000003a5b",
        first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        fourth_topic: nil,
        index: 2,
        second_topic: nil,
        third_topic: nil,
        # block_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
        transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
        block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
        type: "mined"
      }

      expected = %{
        tokens: [
          %{
            contract_address_hash: "0x58Ab73CB79c8275628E0213742a85B163fE0A9Fb",
            type: "ERC-721"
          }
        ],
        token_transfers: [
          %{
            block_number: log.block_number,
            log_index: log.index,
            from_address_hash: "0x58ab73cb79c8275628e0213742a85b163fe0a9fb",
            to_address_hash: "0xbe8cdfc13ffda20c844ac3da2b53a23ac5787f1e",
            block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
            token_contract_address_hash: log.address_hash,
            token_ids: [14_939],
            transaction_hash: log.transaction_hash,
            # block_hash: log.block_hash,
            token_type: "ERC-721"
          }
        ]
      }

      assert TokenTransfers.parse([log]) == expected
    end

    test "parses erc1155 token transfer" do
      log = %{
        address_hash: "0x58Ab73CB79c8275628E0213742a85B163fE0A9Fb",
        block_number: 8_683_457,
        data:
          "0x1000000000000c520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001",
        first_topic: "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62",
        secon_topic: "0x0000000000000000000000009c978f4cfa1fe13406bcc05baf26a35716f881dd",
        third_topic: "0x0000000000000000000000009c978f4cfa1fe13406bcc05baf26a35716f881dd",
        fourth_topic: "0x0000000000000000000000009c978f4cfa1fe13406bcc05baf26a35716f881dd",
        index: 2,
        transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
        block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
        type: "mined"
      }

      assert TokenTransfers.parse([log]) == %{
               token_transfers: [
                 %{
                   amount: 1,
                   block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
                   block_number: 8_683_457,
                   from_address_hash: "0x9c978f4cfa1fe13406bcc05baf26a35716f881dd",
                   log_index: 2,
                   to_address_hash: "0x9c978f4cfa1fe13406bcc05baf26a35716f881dd",
                   token_contract_address_hash: "0x58Ab73CB79c8275628E0213742a85B163fE0A9Fb",
                   token_ids: [
                     7_237_005_577_332_282_011_952_059_972_634_123_378_909_214_838_582_411_639_295_170_840_059_424_276_480
                   ],
                   token_type: "ERC-1155",
                   transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8"
                 }
               ],
               tokens: [
                 %{
                   contract_address_hash: "0x58Ab73CB79c8275628E0213742a85B163fE0A9Fb",
                   type: "ERC-1155"
                 }
               ]
             }
    end

    test "parses erc1155 batch token transfer" do
      log = %{
        address_hash: "0x58Ab73CB79c8275628E0213742a85B163fE0A9Fb",
        block_number: 8_683_457,
        data:
          "0x000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000001388",
        first_topic: "0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb",
        secon_topic: "0x0000000000000000000000006c943470780461b00783ad530a53913bd2c104d3",
        third_topic: "0x0000000000000000000000006c943470780461b00783ad530a53913bd2c104d3",
        fourth_topic: "0x0000000000000000000000006c943470780461b00783ad530a53913bd2c104d3",
        index: 2,
        transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
        block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
        type: "mined"
      }

      assert TokenTransfers.parse([log]) == %{
               token_transfers: [
                 %{
                   block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
                   block_number: 8_683_457,
                   from_address_hash: "0x6c943470780461b00783ad530a53913bd2c104d3",
                   log_index: 2,
                   to_address_hash: "0x6c943470780461b00783ad530a53913bd2c104d3",
                   token_contract_address_hash: "0x58Ab73CB79c8275628E0213742a85B163fE0A9Fb",
                   token_ids: [680_564_733_841_876_926_926_749_214_863_536_422_912],
                   token_type: "ERC-1155",
                   transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
                   amounts: [5000]
                 }
               ],
               tokens: [%{contract_address_hash: "0x58Ab73CB79c8275628E0213742a85B163fE0A9Fb", type: "ERC-1155"}]
             }
    end

    test "logs error with unrecognized token transfer format" do
      log = %{
        address_hash: "0x58Ab73CB79c8275628E0213742a85B163fE0A9Fb",
        block_number: 8_683_457,
        block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
        data: "0x",
        first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        fourth_topic: nil,
        index: 2,
        second_topic: nil,
        third_topic: nil,
        transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
        # block_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
        type: "mined"
      }

      error = capture_log(fn -> %{tokens: [], token_transfers: []} = TokenTransfers.parse([log]) end)
      assert error =~ ~r"unknown token transfer"i
    end
  end

  test "parses itx without duplicate ids" do
    # values below taken from problematic CELO transfers at https://github.com/celo-org/data-services/issues/331
    itxi_txi_pairs = [
      {114, 5},
      {158, 11},
      {323, 11},
      {446, 11},
      {568, 11},
      {758, 11},
      {907, 11},
      {1134, 11},
      {1258, 11},
      {1395, 11},
      {134, 12},
      {175, 13},
      {34, 2}
    ]

    test_itx_maps =
      itxi_txi_pairs
      |> Enum.map(fn {itx_i, tx_i} ->
        %{
          value: 1,
          block_number: 13_606_235,
          block_hash: "0xtestdata",
          from_address_hash: "0xfrom",
          to_address_hash: "0xto",
          index: itx_i,
          transaction_index: tx_i,
          transaction_hash: "0xtransaction hash"
        }
      end)

    %{token_transfers: result_itx} = TokenTransfers.parse_itx(test_itx_maps, "0xgoldtokenaddresshash")

    %{token_transfers: result_tx} =
      TokenTransfers.parse([
        %{
          address_hash: "0xf2eec76e45b328df99a34fa696320a262cb92154",
          block_number: 3_530_917,
          block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
          data: "0x000000000000000000000000000000000000000000000000ebec21ee1da40000",
          first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          fourth_topic: nil,
          index: 0,
          second_topic: "0x000000000000000000000000556813d9cc20acfe8388af029a679d34a63388db",
          third_topic: "0x00000000000000000000000092148dd870fa1b7c4700f2bd7f44238821c26f73",
          transaction_hash: "0x43dfd761974e8c3351d285ab65bee311454eb45b149a015fe7804a33252f19e5",
          type: "mined"
        },
        %{
          address_hash: "0xf2eec76e45b328df99a34fa696320a262cb92154",
          block_number: 3_530_917,
          block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
          data: "0x000000000000000000000000000000000000000000000000ebec21ee1da40000",
          first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          fourth_topic: nil,
          index: 1,
          second_topic: "0x000000000000000000000000556813d9cc20acfe8388af029a679d34a63388db",
          third_topic: "0x00000000000000000000000092148dd870fa1b7c4700f2bd7f44238821c26f73",
          transaction_hash: "0x43dfd761974e8c3351d285ab65bee311454eb45b149a015fe7804a33252f19e5",
          type: "mined"
        },
        %{
          address_hash: "0xf2eec76e45b328df99a34fa696320a262cb92154",
          block_number: 3_530_917,
          block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
          data: "0x000000000000000000000000000000000000000000000000ebec21ee1da40000",
          first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          fourth_topic: nil,
          index: 2,
          second_topic: "0x000000000000000000000000556813d9cc20acfe8388af029a679d34a63388db",
          third_topic: "0x00000000000000000000000092148dd870fa1b7c4700f2bd7f44238821c26f73",
          transaction_hash: "0x43dfd761974e8c3351d285ab65bee311454eb45b149a015fe7804a33252f19e5",
          type: "mined"
        }
      ])

    # create a map of log_index -> count of log_index in result
    log_indexes =
      Enum.concat(result_itx, result_tx)
      |> Enum.map(& &1.log_index)
      |> Enum.reduce(%{}, &Map.put(&2, &1, Map.get(&2, &1, 0) + 1))

    log_indexes
    |> Enum.each(fn {index, count} ->
      assert count == 1, "Index #{index} should be unique but was found #{count} times"
      assert index in -2_147_483_648..2_147_483_647
    end)
  end

  test "creates log indices within the valid range for postgres integer field" do
    itxi_txi_pairs = [
      {407, 26},
      {39, 34},
      # max tx_i found from sampling 10000000 values in live data
      {39, 199},
      # 1000 transactions in block
      {39, 1000},
      # 9000 transactions in block
      {39, 9000}
    ]

    test_itx_maps =
      itxi_txi_pairs
      |> Enum.map(fn {itx_i, tx_i} ->
        %{
          value: 1,
          block_number: 13_606_235,
          block_hash: "0xtestdata",
          from_address_hash: "0xfrom",
          to_address_hash: "0xto",
          index: itx_i,
          transaction_index: tx_i,
          transaction_hash: "0xtransaction hash"
        }
      end)

    %{token_transfers: result} = TokenTransfers.parse_itx(test_itx_maps, "0xgoldtokenaddresshash")

    # require IEx; IEx.pry
    for transfer <- result, do: assert(transfer.log_index in -2_147_483_648..2_147_483_647)
  end

  defp truncated_hash("0x000000000000000000000000" <> rest) do
    "0x" <> rest
  end
end
