defmodule Indexer.Transform.TokenTransfersTest do
  use Explorer.DataCase

  import ExUnit.CaptureLog

  alias Indexer.Transform.TokenTransfers

  describe "parse/1" do
    test "parse/1 parses logs for tokens and token transfers" do
      [log_1, _log_2, log_3, weth_deposit_log, weth_withdrawal_log] =
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
            transaction_hash: "0x43dfd761974e8c3351d285ab65bee311454eb45b149a015fe7804a33252f19e5"
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
            transaction_hash: "0x8425a9b81a9bd1c64861110c1a453b84719cb0361d6fa0db68abf7611b9a890e"
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
            transaction_hash: "0x4011d9a930a3da620321589a54dc0ca3b88216b4886c7a7c3aaad1fb17702d35"
          },
          %{
            address_hash: "0x0BE9e53fd7EDaC9F859882AfdDa116645287C629",
            block_number: 23_704_638,
            block_hash: "0x8f61c99b0dd1196714ffda5bf979a282e6a62fdd3cff25c291284e6b57de2106",
            data: "0x00000000000000000000000000000000000000000000002be19edfcf6b480000",
            first_topic: "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c",
            second_topic: "0x000000000000000000000000fb76e9e7d88e308ab530330ed90e84a952570319",
            third_topic: nil,
            fourth_topic: nil,
            index: 1,
            transaction_hash: "0x185889bc91372106ecf114a4e23f4ee615e131ae3e698078bd5d2ed7e3f55a49"
          },
          %{
            address_hash: "0x0BE9e53fd7EDaC9F859882AfdDa116645287C629",
            block_number: 23_704_608,
            block_hash: "0x5a5e69984f78d65fc6d92e18058d21a9b114f1d56d06ca7aa017b3d87bf0491a",
            data: "0x00000000000000000000000000000000000000000000000000e1315e1ebd28e8",
            first_topic: "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65",
            second_topic: "0x000000000000000000000000e3f85aad0c8dd7337427b9df5d0fb741d65eeeb5",
            third_topic: nil,
            fourth_topic: nil,
            index: 1,
            transaction_hash: "0x07510dbfddbac9064f7d607c2d9a14aa26fa19cdfcd578c0b585ff2395df543f"
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
          },
          %{
            contract_address_hash: weth_withdrawal_log.address_hash,
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
            block_hash: log_1.block_hash
          },
          %{
            amount: Decimal.new("63386150072297704"),
            block_hash: weth_withdrawal_log.block_hash,
            block_number: weth_withdrawal_log.block_number,
            from_address_hash: truncated_hash(weth_withdrawal_log.second_topic),
            log_index: 1,
            to_address_hash: "0x0000000000000000000000000000000000000000",
            token_contract_address_hash: weth_withdrawal_log.address_hash,
            token_ids: nil,
            token_type: "ERC-20",
            transaction_hash: weth_withdrawal_log.transaction_hash
          },
          %{
            amount: Decimal.new("809467672956315893760"),
            block_hash: weth_deposit_log.block_hash,
            block_number: weth_deposit_log.block_number,
            from_address_hash: "0x0000000000000000000000000000000000000000",
            log_index: 1,
            to_address_hash: truncated_hash(weth_deposit_log.second_topic),
            token_contract_address_hash: weth_deposit_log.address_hash,
            token_ids: nil,
            token_type: "ERC-20",
            transaction_hash: weth_deposit_log.transaction_hash
          }
        ]
      }

      env = Application.get_env(:explorer, Explorer.Chain.TokenTransfer)

      Application.put_env(
        :explorer,
        Explorer.Chain.TokenTransfer,
        Keyword.put(env, :whitelisted_weth_contracts, [
          weth_deposit_log.address_hash |> to_string() |> String.downcase()
        ])
      )

      assert TokenTransfers.parse(logs) == expected

      Application.put_env(:explorer, Explorer.Chain.TokenTransfer, env)
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
        transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
        block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca"
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
        second_topic: "0x0000000000000000000000009c978f4cfa1fe13406bcc05baf26a35716f881dd",
        third_topic: "0x0000000000000000000000009c978f4cfa1fe13406bcc05baf26a35716f881dd",
        fourth_topic: "0x0000000000000000000000009c978f4cfa1fe13406bcc05baf26a35716f881dd",
        index: 2,
        transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
        block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca"
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
        second_topic: "0x0000000000000000000000006c943470780461b00783ad530a53913bd2c104d3",
        third_topic: "0x0000000000000000000000006c943470780461b00783ad530a53913bd2c104d3",
        fourth_topic: "0x0000000000000000000000006c943470780461b00783ad530a53913bd2c104d3",
        index: 2,
        transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8",
        block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca"
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

    test "parses erc1155 batch token transfer with empty ids/values" do
      log = %{
        address_hash: "0x598AF04C88122FA4D1e08C5da3244C39F10D4F14",
        block_number: 9_065_059,
        data:
          "0x0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        first_topic: "0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb",
        second_topic: "0x81D0caF80E9bFfD9bF9c641ab964feB9ef69069e",
        third_topic: "0x598AF04C88122FA4D1e08C5da3244C39F10D4F14",
        fourth_topic: "0x0000000000000000000000000000000000000000",
        index: 6,
        transaction_hash: "0xa6ad6588edb4abd8ca45f30d2f026ba20b68a3002a5870dbd30cc3752568483b",
        block_hash: "0x61b720e40f8c521edd77a52cabce556c18b18b198f78e361f310003386ff1f02"
      }

      assert TokenTransfers.parse([log]) == %{
               token_transfers: [],
               tokens: []
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
        transaction_hash: "0x6d2dd62c178e55a13b65601f227c4ffdd8aa4e3bcb1f24731363b4f7619e92c8"
      }

      error = capture_log(fn -> %{tokens: [], token_transfers: []} = TokenTransfers.parse([log]) end)
      assert error =~ ~r"unknown token transfer"i
    end

    test "token type from database is preferred if the incoming one is different" do
      %{contract_address_hash: hash} = insert(:token, type: "ERC-1155")

      contract_address_hash = to_string(hash)

      log = %{
        address_hash: contract_address_hash,
        block_number: 3_530_917,
        block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
        data: "0x000000000000000000000000000000000000000000000000ebec21ee1da40000",
        first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        fourth_topic: nil,
        index: 8,
        second_topic: "0x000000000000000000000000556813d9cc20acfe8388af029a679d34a63388db",
        third_topic: "0x00000000000000000000000092148dd870fa1b7c4700f2bd7f44238821c26f73",
        transaction_hash: "0x43dfd761974e8c3351d285ab65bee311454eb45b149a015fe7804a33252f19e5"
      }

      assert %{
               token_transfers: [%{token_contract_address_hash: ^contract_address_hash, token_type: "ERC-20"}],
               tokens: [%{contract_address_hash: ^contract_address_hash, type: "ERC-1155"}]
             } = TokenTransfers.parse([log])
    end

    test "if there are transfers of different token types, the highest priority will be selected for all" do
      contract_address_hash = "0x0000000000000000000000000000000000000001"

      logs = [
        %{
          address_hash: contract_address_hash,
          block_number: 3_530_917,
          block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
          data: "0x000000000000000000000000000000000000000000000000ebec21ee1da40000",
          first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          fourth_topic: nil,
          index: 8,
          second_topic: "0x000000000000000000000000556813d9cc20acfe8388af029a679d34a63388db",
          third_topic: "0x00000000000000000000000092148dd870fa1b7c4700f2bd7f44238821c26f73",
          transaction_hash: "0x43dfd761974e8c3351d285ab65bee311454eb45b149a015fe7804a33252f19e5"
        },
        %{
          address_hash: contract_address_hash,
          block_number: 3_530_917,
          data:
            "0x1000000000000c520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001",
          first_topic: "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62",
          second_topic: "0x0000000000000000000000009c978f4cfa1fe13406bcc05baf26a35716f881dd",
          third_topic: "0x0000000000000000000000009c978f4cfa1fe13406bcc05baf26a35716f881dd",
          fourth_topic: "0x0000000000000000000000009c978f4cfa1fe13406bcc05baf26a35716f881dd",
          index: 2,
          transaction_hash: "0x43dfd761974e8c3351d285ab65bee311454eb45b149a015fe7804a33252f19e5",
          block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca"
        }
      ]

      assert %{
               token_transfers: [
                 %{token_contract_address_hash: ^contract_address_hash, token_type: "ERC-1155"},
                 %{token_contract_address_hash: ^contract_address_hash, token_type: "ERC-20"}
               ],
               tokens: [%{contract_address_hash: ^contract_address_hash, type: "ERC-1155"}]
             } = TokenTransfers.parse(logs)
    end

    test "parses erc404 token transfer from ERC20Transfer" do
      log = %{
        address_hash: "0x03F6CCfCE60273eFbEB9535675C8EFA69D863f37",
        block_number: 10_561_358,
        data: "0x00000000000000000000000000000000000000000000003635c9adc5de9ffc48",
        first_topic: "0xe59fdd36d0d223c0c7d996db7ad796880f45e1936cb0bb7ac102e7082e031487",
        second_topic: "0x000000000000000000000000c36442b4a4522e871399cd717abdd847ab11fe88",
        third_topic: "0x00000000000000000000000018336808ed2f2c80795861041f711b299ecd38ca",
        fourth_topic: nil,
        index: 34,
        transaction_hash: "0x6be468f465911ec70103aa83e38c84697848feaf760eee3a181ebcdcab82dc4a",
        block_hash: "0x7cffabfd975bded1ec397f44b4af3a97618b96ca0e2f92d70a3025ba233815ca"
      }

      assert TokenTransfers.parse([log]) == %{
               token_transfers: [
                 %{
                   block_hash: "0x7cffabfd975bded1ec397f44b4af3a97618b96ca0e2f92d70a3025ba233815ca",
                   block_number: 10_561_358,
                   from_address_hash: "0xc36442b4a4522e871399cd717abdd847ab11fe88",
                   log_index: 34,
                   to_address_hash: "0x18336808ed2f2c80795861041f711b299ecd38ca",
                   token_contract_address_hash: "0x03F6CCfCE60273eFbEB9535675C8EFA69D863f37",
                   amounts: [
                     999_999_999_999_999_999_048
                   ],
                   token_ids: [],
                   token_type: "ERC-404",
                   transaction_hash: "0x6be468f465911ec70103aa83e38c84697848feaf760eee3a181ebcdcab82dc4a"
                 }
               ],
               tokens: [
                 %{
                   contract_address_hash: "0x03F6CCfCE60273eFbEB9535675C8EFA69D863f37",
                   type: "ERC-404"
                 }
               ]
             }
    end

    test "parses erc404 token transfer from ERC721Transfer" do
      log = %{
        address_hash: "0x68995c84aFb019913942E53F27E7ceA47D86Cd9d",
        block_number: 10_514_498,
        data: "0x",
        first_topic: "0xe5f815dc84b8cecdfd4beedfc3f91ab5be7af100eca4e8fb11552b867995394f",
        second_topic: "0x000000000000000000000000fd7ec4d8b6ba1a72f3895b6ce3846b00d6b83aab",
        third_topic: "0x0000000000000000000000007a250d5630b4cf539739df2c5dacb4c659f2488d",
        fourth_topic: "0x000000000000000000000000000000000000000000000000000000000000000a",
        index: 41,
        transaction_hash: "0xe201aed9c948f46395c6acc54de5e9c3ebe0c41a5c34cc6a507b67ec46057c55",
        block_hash: "0xea065ff2fc04177bbef27317209a25f2633199aa453b86ee405b619c495b2e77"
      }

      assert TokenTransfers.parse([log]) == %{
               token_transfers: [
                 %{
                   block_hash: "0xea065ff2fc04177bbef27317209a25f2633199aa453b86ee405b619c495b2e77",
                   block_number: 10_514_498,
                   from_address_hash: "0xfd7ec4d8b6ba1a72f3895b6ce3846b00d6b83aab",
                   log_index: 41,
                   to_address_hash: "0x7a250d5630b4cf539739df2c5dacb4c659f2488d",
                   token_contract_address_hash: "0x68995c84aFb019913942E53F27E7ceA47D86Cd9d",
                   amounts: [],
                   token_ids: [10],
                   token_type: "ERC-404",
                   transaction_hash: "0xe201aed9c948f46395c6acc54de5e9c3ebe0c41a5c34cc6a507b67ec46057c55"
                 }
               ],
               tokens: [
                 %{
                   contract_address_hash: "0x68995c84aFb019913942E53F27E7ceA47D86Cd9d",
                   type: "ERC-404"
                 }
               ]
             }
    end

    test "Filters WETH transfers from not whitelisted tokens" do
      logs = [
        %{
          address_hash: "0x0BE9e53fd7EDaC9F859882AfdDa116645287C629",
          block_number: 23_704_638,
          block_hash: "0x8f61c99b0dd1196714ffda5bf979a282e6a62fdd3cff25c291284e6b57de2106",
          data: "0x00000000000000000000000000000000000000000000002be19edfcf6b480000",
          first_topic: "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c",
          second_topic: "0x000000000000000000000000fb76e9e7d88e308ab530330ed90e84a952570319",
          third_topic: nil,
          fourth_topic: nil,
          index: 1,
          transaction_hash: "0x185889bc91372106ecf114a4e23f4ee615e131ae3e698078bd5d2ed7e3f55a49"
        },
        %{
          address_hash: "0x0BE9e53fd7EDaC9F859882AfdDa116645287C629",
          block_number: 23_704_608,
          block_hash: "0x5a5e69984f78d65fc6d92e18058d21a9b114f1d56d06ca7aa017b3d87bf0491a",
          data: "0x00000000000000000000000000000000000000000000000000e1315e1ebd28e8",
          first_topic: "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65",
          second_topic: "0x000000000000000000000000e3f85aad0c8dd7337427b9df5d0fb741d65eeeb5",
          third_topic: nil,
          fourth_topic: nil,
          index: 1,
          transaction_hash: "0x07510dbfddbac9064f7d607c2d9a14aa26fa19cdfcd578c0b585ff2395df543f"
        }
      ]

      expected = %{token_transfers: [], tokens: []}

      assert TokenTransfers.parse(logs) == expected
    end

    test "Filters duplicates WETH transfers" do
      [log_1, _weth_deposit_log, log_2, _weth_withdrawal_log] =
        logs = [
          %{
            address_hash: "0x0BE9e53fd7EDaC9F859882AfdDa116645287C629",
            block_number: 23_704_638,
            block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
            data: "0x00000000000000000000000000000000000000000000002be19edfcf6b480000",
            first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            fourth_topic: nil,
            index: 1,
            second_topic: "0x0000000000000000000000000000000000000000000000000000000000000000",
            third_topic: "0x000000000000000000000000fb76e9e7d88e308ab530330ed90e84a952570319",
            transaction_hash: "0x4011d9a930a3da620321589a54dc0ca3b88216b4886c7a7c3aaad1fb17702d35"
          },
          %{
            address_hash: "0x0BE9e53fd7EDaC9F859882AfdDa116645287C629",
            block_number: 23_704_638,
            block_hash: "0x79594150677f083756a37eee7b97ed99ab071f502104332cb3835bac345711ca",
            data: "0x00000000000000000000000000000000000000000000002be19edfcf6b480000",
            first_topic: "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c",
            second_topic: "0x000000000000000000000000fb76e9e7d88e308ab530330ed90e84a952570319",
            third_topic: nil,
            fourth_topic: nil,
            index: 2,
            transaction_hash: "0x4011d9a930a3da620321589a54dc0ca3b88216b4886c7a7c3aaad1fb17702d35"
          },
          %{
            address_hash: "0xf2eec76e45b328df99a34fa696320a262cb92154",
            block_number: 3_530_917,
            block_hash: "0x5a5e69984f78d65fc6d92e18058d21a9b114f1d56d06ca7aa017b3d87bf0491a",
            data: "0x00000000000000000000000000000000000000000000000000e1315e1ebd28e8",
            first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            fourth_topic: nil,
            index: 8,
            second_topic: "0x000000000000000000000000e3f85aad0c8dd7337427b9df5d0fb741d65eeeb5",
            third_topic: "0x0000000000000000000000000000000000000000000000000000000000000000",
            transaction_hash: "0x185889bc91372106ecf114a4e23f4ee615e131ae3e698078bd5d2ed7e3f55a49"
          },
          %{
            address_hash: "0xf2eec76e45b328df99a34fa696320a262cb92154",
            block_number: 3_530_917,
            block_hash: "0x5a5e69984f78d65fc6d92e18058d21a9b114f1d56d06ca7aa017b3d87bf0491a",
            data: "0x00000000000000000000000000000000000000000000000000e1315e1ebd28e8",
            first_topic: "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65",
            second_topic: "0x000000000000000000000000e3f85aad0c8dd7337427b9df5d0fb741d65eeeb5",
            third_topic: nil,
            fourth_topic: nil,
            index: 1,
            transaction_hash: "0x185889bc91372106ecf114a4e23f4ee615e131ae3e698078bd5d2ed7e3f55a49"
          }
        ]

      expected = %{
        tokens: [
          %{
            contract_address_hash: log_2.address_hash,
            type: "ERC-20"
          },
          %{
            contract_address_hash: log_1.address_hash,
            type: "ERC-20"
          }
        ],
        token_transfers: [
          %{
            token_ids: nil,
            amount: Decimal.new(63_386_150_072_297_704),
            block_number: log_2.block_number,
            log_index: log_2.index,
            from_address_hash: truncated_hash(log_2.second_topic),
            to_address_hash: truncated_hash(log_2.third_topic),
            token_contract_address_hash: log_2.address_hash,
            transaction_hash: log_2.transaction_hash,
            token_type: "ERC-20",
            block_hash: log_2.block_hash
          },
          %{
            block_number: log_1.block_number,
            log_index: log_1.index,
            from_address_hash: truncated_hash(log_1.second_topic),
            to_address_hash: truncated_hash(log_1.third_topic),
            token_contract_address_hash: log_1.address_hash,
            token_ids: nil,
            transaction_hash: log_1.transaction_hash,
            token_type: "ERC-20",
            block_hash: log_1.block_hash,
            amount: Decimal.new(809_467_672_956_315_893_760)
          }
        ]
      }

      env = Application.get_env(:explorer, Explorer.Chain.TokenTransfer)

      Application.put_env(
        :explorer,
        Explorer.Chain.TokenTransfer,
        Keyword.put(env, :whitelisted_weth_contracts, [
          log_1.address_hash |> to_string() |> String.downcase(),
          log_2.address_hash |> to_string() |> String.downcase()
        ])
      )

      assert TokenTransfers.parse(logs) == expected

      Application.put_env(:explorer, Explorer.Chain.TokenTransfer, env)
    end
  end

  defp truncated_hash("0x000000000000000000000000" <> rest) do
    "0x" <> rest
  end
end
