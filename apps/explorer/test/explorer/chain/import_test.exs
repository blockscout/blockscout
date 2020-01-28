defmodule Explorer.Chain.ImportTest do
  use Explorer.DataCase

  alias Explorer.Chain

  alias Explorer.Chain.{
    Address,
    Address.TokenBalance,
    Address.CurrentTokenBalance,
    Block,
    Data,
    Log,
    Hash,
    Import,
    PendingBlockOperation,
    Token,
    TokenTransfer,
    Transaction
  }

  alias Explorer.Chain.Events.Subscriber

  @moduletag :capturelog

  doctest Import

  describe "all/1" do
    # set :timeout options to cover lines that use the timeout override when available
    @import_data %{
      blocks: %{
        params: [
          %{
            consensus: true,
            difficulty: 340_282_366_920_938_463_463_374_607_431_768_211_454,
            gas_limit: 6_946_336,
            gas_used: 50450,
            hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            nonce: 0,
            number: 37,
            parent_hash: "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
            size: 719,
            timestamp: Timex.parse!("2017-12-15T21:06:30.000000Z", "{ISO:Extended:Z}"),
            total_difficulty: 12_590_447_576_074_723_148_144_860_474_975_121_280_509
          }
        ],
        timeout: 5
      },
      broadcast: :realtime,
      internal_transactions: %{
        params: [
          %{
            block_number: 37,
            transaction_index: 0,
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            index: 0,
            trace_address: [],
            type: "call",
            call_type: "call",
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            gas: 4_677_320,
            gas_used: 27770,
            input: "0x",
            output: "0x",
            value: 0
          },
          %{
            block_number: 37,
            transaction_index: 1,
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            index: 1,
            trace_address: [0],
            type: "call",
            call_type: "call",
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            gas: 4_677_320,
            gas_used: 27770,
            input: "0x",
            output: "0x",
            value: 0
          }
        ],
        timeout: 5,
        with: :blockless_changeset
      },
      logs: %{
        params: [
          %{
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            data: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            second_topic: "0x000000000000000000000000e8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            third_topic: "0x000000000000000000000000515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            fourth_topic: nil,
            index: 0,
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "mined"
          }
        ],
        timeout: 5
      },
      transactions: %{
        params: [
          %{
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            block_number: 37,
            cumulative_gas_used: 50450,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_700_000,
            gas_price: 100_000_000_000,
            gas_used: 50450,
            hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            index: 0,
            input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
            nonce: 4,
            public_key:
              "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
            r: 0xA7F8F45CCE375BB7AF8750416E1B03E0473F93C256DA2285D1134FC97A700E01,
            s: 0x1F87A076F13824F4BE8963E3DFFD7300DAE64D5F23C9A062AF0C6EAD347C135F,
            standard_v: 1,
            status: :ok,
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            v: 0xBE,
            value: 0
          }
        ],
        timeout: 5
      },
      addresses: %{
        params: [
          %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"},
          %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"},
          %{hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d"}
        ],
        timeout: 5
      },
      tokens: %{
        on_conflict: :nothing,
        params: [
          %{
            contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            type: "ERC-20"
          }
        ],
        timeout: 5
      },
      token_transfers: %{
        params: [
          %{
            amount: Decimal.new(1_000_000_000_000_000_000),
            block_number: 37,
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            log_index: 0,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            to_address_hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
          }
        ],
        timeout: 5
      }
    }

    test "with valid data" do
      difficulty = Decimal.new(340_282_366_920_938_463_463_374_607_431_768_211_454)
      total_difficulty = Decimal.new(12_590_447_576_074_723_148_144_860_474_975_121_280_509)
      token_transfer_amount = Decimal.new(1_000_000_000_000_000_000)
      gas_limit = Decimal.new(6_946_336)
      gas_used = Decimal.new(50450)

      assert {:ok,
              %{
                addresses: [
                  %Address{
                    hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<81, 92, 9, 197, 187, 161, 237, 86, 107, 2, 165, 176, 89, 158, 197, 213, 208, 174, 231, 61>>
                    },
                    inserted_at: %{},
                    updated_at: %{}
                  },
                  %Address{
                    hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65,
                          91>>
                    },
                    inserted_at: %{},
                    updated_at: %{}
                  },
                  %Address{
                    hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122,
                          202>>
                    },
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ],
                blocks: [
                  %Block{
                    difficulty: ^difficulty,
                    gas_limit: ^gas_limit,
                    gas_used: ^gas_used,
                    hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<246, 180, 184, 200, 141, 243, 235, 210, 82, 236, 71, 99, 40, 51, 77, 192, 38, 207, 102, 96,
                          106, 132, 251, 118, 155, 61, 60, 188, 204, 132, 113, 189>>
                    },
                    miner_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122,
                          202>>
                    },
                    nonce: %Explorer.Chain.Hash{
                      byte_count: 8,
                      bytes: <<0, 0, 0, 0, 0, 0, 0, 0>>
                    },
                    number: 37,
                    parent_hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<195, 123, 186, 215, 5, 121, 69, 209, 191, 18, 140, 31, 240, 9, 251, 26, 214, 50, 17, 11, 246,
                          160, 0, 170, 192, 37, 168, 15, 119, 102, 182, 110>>
                    },
                    size: 719,
                    timestamp: %DateTime{
                      year: 2017,
                      month: 12,
                      day: 15,
                      hour: 21,
                      minute: 6,
                      second: 30,
                      microsecond: {0, 6},
                      std_offset: 0,
                      utc_offset: 0,
                      time_zone: "Etc/UTC",
                      zone_abbr: "UTC"
                    },
                    total_difficulty: ^total_difficulty,
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ],
                internal_transactions: [
                  %{
                    index: 0,
                    transaction_hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    }
                  },
                  %{
                    index: 1,
                    transaction_hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    }
                  }
                ],
                logs: [
                  %Log{
                    address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65,
                          91>>
                    },
                    data: %Data{
                      bytes:
                        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 224, 182, 179,
                          167, 100, 0, 0>>
                    },
                    index: 0,
                    first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                    second_topic: "0x000000000000000000000000e8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                    third_topic: "0x000000000000000000000000515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
                    fourth_topic: nil,
                    transaction_hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    },
                    type: "mined",
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ],
                transactions: [
                  %Transaction{
                    block_number: 37,
                    index: 0,
                    hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    }
                  }
                ],
                tokens: [
                  %Token{
                    contract_address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65,
                          91>>
                    },
                    type: "ERC-20",
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ],
                token_transfers: [
                  %TokenTransfer{
                    amount: ^token_transfer_amount,
                    log_index: 0,
                    from_address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122,
                          202>>
                    },
                    to_address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<81, 92, 9, 197, 187, 161, 237, 86, 107, 2, 165, 176, 89, 158, 197, 213, 208, 174, 231, 61>>
                    },
                    token_contract_address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65,
                          91>>
                    },
                    transaction_hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    },
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ]
              }} = Import.all(@import_data)
    end

    test "inserts a token_balance" do
      params = %{
        addresses: %{
          params: [
            %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"},
            %{hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d"},
            %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}
          ],
          timeout: 5
        },
        tokens: %{
          on_conflict: :nothing,
          params: [
            %{
              contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              type: "ERC-20"
            }
          ],
          timeout: 5
        },
        address_token_balances: %{
          params: [
            %{
              address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
              token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              block_number: "37"
            },
            %{
              address_hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
              token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              block_number: "37"
            },
            %{
              address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              block_number: "37"
            }
          ],
          timeout: 5
        }
      }

      Import.all(params)

      count = Explorer.Repo.one(Ecto.Query.from(t in TokenBalance, select: count(t.id)))

      assert 3 == count
    end

    test "inserts a current_token_balance" do
      params = %{
        addresses: %{
          params: [
            %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"},
            %{hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d"},
            %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}
          ],
          timeout: 5
        },
        tokens: %{
          on_conflict: :nothing,
          params: [
            %{
              contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              type: "ERC-20"
            }
          ],
          timeout: 5
        },
        address_current_token_balances: %{
          params: [
            %{
              address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
              token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              block_number: "37",
              value: 200
            },
            %{
              address_hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
              token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              block_number: "37",
              value: 100
            }
          ],
          timeout: 5
        }
      }

      Import.all(params)

      count =
        CurrentTokenBalance
        |> Explorer.Repo.all()
        |> Enum.count()

      assert count == 2
    end

    test "with empty map" do
      assert {:ok, %{}} == Import.all(%{})
    end

    test "with invalid data" do
      invalid_import_data =
        update_in(@import_data, [:internal_transactions, :params, Access.at(0)], &Map.delete(&1, :call_type))

      assert {:error, [changeset]} = Import.all(invalid_import_data)
      assert changeset_errors(changeset)[:call_type] == ["can't be blank"]
    end

    test "publishes addresses with updated fetched_coin_balance data to subscribers on insert" do
      Subscriber.to(:addresses, :realtime)
      Import.all(@import_data)
      assert_receive {:chain_event, :addresses, :realtime, [%Address{}, %Address{}, %Address{}]}
    end

    test "publishes block data to subscribers on insert" do
      Subscriber.to(:blocks, :realtime)
      Import.all(@import_data)
      assert_receive {:chain_event, :blocks, :realtime, [%Block{}]}
    end

    test "publishes internal_transaction data to subscribers on insert" do
      Subscriber.to(:internal_transactions, :realtime)
      Import.all(@import_data)

      assert_receive {:chain_event, :internal_transactions, :realtime,
                      [%{transaction_hash: _, index: _}, %{transaction_hash: _, index: _}]}
    end

    test "publishes transactions data to subscribers on insert" do
      Subscriber.to(:transactions, :realtime)
      Import.all(@import_data)
      assert_receive {:chain_event, :transactions, :realtime, [%Transaction{}]}
    end

    test "publishes token_transfers data to subscribers on insert" do
      Subscriber.to(:token_transfers, :realtime)

      Import.all(@import_data)

      assert_receive {:chain_event, :token_transfers, :realtime, [%TokenTransfer{}]}
    end

    test "does not broadcast if broadcast option is false" do
      non_broadcast_data = Map.merge(@import_data, %{broadcast: false})

      Subscriber.to(:addresses, :realtime)
      Import.all(non_broadcast_data)
      refute_received {:chain_event, :addresses, :realtime, [%Address{}]}
    end

    test "updates address with contract code" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      address_hash = "0x1c494fa496f1cfd918b5ff190835af3aaf60987e"
      insert(:address, hash: address_hash)

      from_address_hash = "0x8cc2e4b51b4340cb3727cffe3f1878756e732cee"
      from_address = insert(:address, hash: from_address_hash)

      block = insert(:block, number: 37)

      transaction_string_hash = "0x0705ea0a5b997d9aafd5c531e016d9aabe3297a28c0bd4ef005fe6ea329d301b"

      :transaction
      |> insert(from_address: from_address, hash: transaction_string_hash)
      |> with_block(block, status: :ok)

      options = %{
        addresses: %{
          params: [
            %{
              contract_code: smart_contract_bytecode,
              hash: address_hash
            }
          ]
        },
        internal_transactions: %{
          params: [
            %{
              created_contract_address_hash: address_hash,
              created_contract_code: smart_contract_bytecode,
              from_address_hash: from_address_hash,
              gas: 184_531,
              gas_used: 84531,
              index: 0,
              init:
                "0x6060604052341561000c57fe5b5b6101a68061001c6000396000f300606060405263ffffffff7c01000000000000000000000000000000000000000000000000000000006000350416631d3b9edf811461005b57806366098d4f1461007b578063a12f69e01461009b578063f4f3bdc1146100bb575bfe5b6100696004356024356100db565b60408051918252519081900360200190f35b61006960043560243561010a565b60408051918252519081900360200190f35b610069600435602435610124565b60408051918252519081900360200190f35b610069600435602435610163565b60408051918252519081900360200190f35b60008282028315806100f757508284828115156100f457fe5b04145b15156100ff57fe5b8091505b5092915050565b6000828201838110156100ff57fe5b8091505b5092915050565b60008080831161013057fe5b828481151561013b57fe5b049050828481151561014957fe5b0681840201841415156100ff57fe5b8091505b5092915050565b60008282111561016f57fe5b508082035b929150505600a165627a7a7230582020c944d8375ca14e2c92b14df53c2d044cb99dc30c3ba9f55e2bcde87bd4709b0029",
              trace_address: [],
              transaction_hash: transaction_string_hash,
              type: "create",
              value: 0,
              block_number: 37,
              transaction_index: 0
            }
          ],
          with: :blockless_changeset
        }
      }

      assert {:ok, _} = Import.all(options)

      address = Explorer.Repo.get(Address, address_hash)

      assert address.contract_code != smart_contract_bytecode
    end

    test "with internal_transactions updates PendingBlockOperation status" do
      block_hash = "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47"
      block_number = 34
      miner_hash = from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

      options = %{
        addresses: %{
          params: [
            %{hash: from_address_hash},
            %{hash: to_address_hash}
          ]
        },
        blocks: %{
          params: [
            %{
              consensus: true,
              difficulty: 340_282_366_920_938_463_463_374_607_431_768_211_454,
              gas_limit: 6_926_030,
              gas_used: 269_607,
              hash: block_hash,
              miner_hash: miner_hash,
              nonce: 0,
              number: block_number,
              parent_hash: "0x106d528393159b93218dd410e2a778f083538098e46f1a44902aa67a164aed0b",
              size: 1493,
              timestamp: Timex.parse!("2017-12-15T21:06:15Z", "{ISO:Extended:Z}"),
              total_difficulty: 11_569_600_475_311_907_757_754_736_652_679_816_646_147
            }
          ]
        },
        transactions: %{
          params: [
            %{
              block_hash: block_hash,
              block_number: block_number,
              cumulative_gas_used: 269_607,
              from_address_hash: from_address_hash,
              gas: 269_607,
              gas_price: 1,
              gas_used: 269_607,
              hash: transaction_hash,
              index: 0,
              input: "0x",
              nonce: 0,
              r: 0,
              s: 0,
              status: :ok,
              v: 0,
              value: 0
            }
          ]
        }
      }

      internal_txs_options = %{
        internal_transactions: %{
          params: [
            %{
              block_number: block_number,
              transaction_index: 0,
              transaction_hash: transaction_hash,
              index: 0,
              trace_address: [],
              type: "call",
              call_type: "call",
              from_address_hash: from_address_hash,
              to_address_hash: to_address_hash,
              gas: 4_677_320,
              gas_used: 27770,
              input: "0x",
              output: "0x",
              value: 0
            }
          ],
          with: :blockless_changeset
        }
      }

      assert {:ok, _} = Import.all(options)

      assert [block_hash] = Explorer.Repo.all(PendingBlockOperation.block_hashes(:fetch_internal_transactions))

      assert {:ok, _} = Import.all(internal_txs_options)

      assert [] == Explorer.Repo.all(PendingBlockOperation.block_hashes(:fetch_internal_transactions))
    end

    test "when the transaction has no to_address and an internal transaction with type create it populates the denormalized created_contract_address_hash" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      block_hash = "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47"
      block_number = 34
      miner_hash = from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      created_contract_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

      options = %{
        addresses: %{
          params: [
            %{hash: from_address_hash},
            %{
              contract_code: smart_contract_bytecode,
              hash: created_contract_address_hash
            }
          ]
        },
        blocks: %{
          params: [
            %{
              consensus: true,
              difficulty: 340_282_366_920_938_463_463_374_607_431_768_211_454,
              gas_limit: 6_926_030,
              gas_used: 269_607,
              hash: block_hash,
              miner_hash: miner_hash,
              nonce: 0,
              number: block_number,
              parent_hash: "0x106d528393159b93218dd410e2a778f083538098e46f1a44902aa67a164aed0b",
              size: 1493,
              timestamp: Timex.parse!("2017-12-15T21:06:15Z", "{ISO:Extended:Z}"),
              total_difficulty: 11_569_600_475_311_907_757_754_736_652_679_816_646_147
            }
          ]
        },
        transactions: %{
          params: [
            %{
              block_hash: block_hash,
              block_number: block_number,
              cumulative_gas_used: 269_607,
              from_address_hash: from_address_hash,
              gas: 269_607,
              gas_price: 1,
              gas_used: 269_607,
              hash: transaction_hash,
              index: 0,
              input: "0x",
              nonce: 0,
              r: 0,
              s: 0,
              status: :ok,
              v: 0,
              value: 0
            }
          ]
        },
        internal_transactions: %{
          params: [
            %{
              block_number: block_number,
              call_type: "call",
              created_contract_code: smart_contract_bytecode,
              created_contract_address_hash: created_contract_address_hash,
              from_address_hash: from_address_hash,
              gas: 4_677_320,
              gas_used: 27770,
              index: 0,
              init:
                "0x6060604052341561000c57fe5b5b6101a68061001c6000396000f300606060405263ffffffff7c01000000000000000000000000000000000000000000000000000000006000350416631d3b9edf811461005b57806366098d4f1461007b578063a12f69e01461009b578063f4f3bdc1146100bb575bfe5b6100696004356024356100db565b60408051918252519081900360200190f35b61006960043560243561010a565b60408051918252519081900360200190f35b610069600435602435610124565b60408051918252519081900360200190f35b610069600435602435610163565b60408051918252519081900360200190f35b60008282028315806100f757508284828115156100f457fe5b04145b15156100ff57fe5b8091505b5092915050565b6000828201838110156100ff57fe5b8091505b5092915050565b60008080831161013057fe5b828481151561013b57fe5b049050828481151561014957fe5b0681840201841415156100ff57fe5b8091505b5092915050565b60008282111561016f57fe5b508082035b929150505600a165627a7a7230582020c944d8375ca14e2c92b14df53c2d044cb99dc30c3ba9f55e2bcde87bd4709b0029",
              output: "0x",
              trace_address: [],
              transaction_hash: transaction_hash,
              type: "create",
              value: 0,
              transaction_index: 0
            }
          ],
          with: :blockless_changeset
        }
      }

      assert {:ok, _} = Import.all(options)

      transaction = Explorer.Repo.get(Transaction, transaction_hash)

      assert {:ok, transaction.created_contract_address_hash} ==
               Chain.string_to_address_hash(created_contract_address_hash)
    end

    test "import balances" do
      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [%{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}]
                 },
                 address_coin_balances: %{
                   params: [%{address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b", block_number: 1}],
                   timeout: 5
                 }
               })
    end

    test "transactions with multiple create uses first internal transaction's created contract address hash" do
      assert {:ok, _} =
               Import.all(%{
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 340_282_366_920_938_463_463_374_607_431_768_211_454,
                       gas_limit: 6_946_336,
                       gas_used: 50450,
                       hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                       miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                       nonce: 0,
                       number: 37,
                       parent_hash: "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
                       size: 719,
                       timestamp: Timex.parse!("2017-12-15T21:06:30.000000Z", "{ISO:Extended:Z}"),
                       total_difficulty: 12_590_447_576_074_723_148_144_860_474_975_121_280_509
                     }
                   ],
                   timeout: 5
                 },
                 transactions: %{
                   params: [
                     %{
                       block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
                       block_number: 37,
                       cumulative_gas_used: 50450,
                       from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                       gas: 4_700_000,
                       gas_price: 100_000_000_000,
                       gas_used: 50450,
                       hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                       index: 0,
                       input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                       nonce: 4,
                       public_key:
                         "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
                       r: 0xA7F8F45CCE375BB7AF8750416E1B03E0473F93C256DA2285D1134FC97A700E01,
                       s: 0x1F87A076F13824F4BE8963E3DFFD7300DAE64D5F23C9A062AF0C6EAD347C135F,
                       standard_v: 1,
                       status: :ok,
                       v: 0xBE,
                       value: 0
                     }
                   ],
                   timeout: 5
                 },
                 internal_transactions: %{
                   params: [
                     %{
                       created_contract_address_hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
                       created_contract_code:
                         "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
                       from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                       gas: 4_677_320,
                       gas_used: 27770,
                       index: 0,
                       init:
                         "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
                       trace_address: [],
                       transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                       type: "create",
                       value: 0,
                       block_number: 37,
                       transaction_index: 0
                     },
                     %{
                       created_contract_address_hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb5",
                       created_contract_code:
                         "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
                       from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                       gas: 4_677_320,
                       gas_used: 27770,
                       index: 1,
                       init:
                         "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
                       trace_address: [],
                       transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                       type: "create",
                       value: 0,
                       block_number: 37,
                       transaction_index: 1
                     }
                   ],
                   timeout: 5,
                   with: :blockless_changeset
                 },
                 addresses: %{
                   params: [
                     %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"},
                     %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"},
                     %{hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4"},
                     %{hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb5"}
                   ],
                   timeout: 5
                 }
               })

      assert %Transaction{created_contract_address_hash: created_contract_address_hash} =
               Repo.get(Transaction, "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5")

      assert to_string(created_contract_address_hash) == "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4"
    end

    test "updates transaction error and status from internal transactions when status is not set from (pre-Byzantium/Ethereum Classic) receipts" do
      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: "0x1c0fa194a9d3b44313dcd849f3c6be6ad270a0a4"},
                     %{hash: "0x679ed2245eba484021c2d3f4d174fb2bb2bd0e49"},
                     %{hash: "0xb7cffe2ac19b9d5705a24cbe14fef5663af905a6"},
                     %{hash: "0xfa52274dd61e1643d2205169732f29114bc240b3"}
                   ]
                 },
                 address_coin_balances: %{
                   params: [
                     %{
                       address_hash: "0x1c0fa194a9d3b44313dcd849f3c6be6ad270a0a4",
                       block_number: 6_535_159
                     },
                     %{
                       address_hash: "0x679ed2245eba484021c2d3f4d174fb2bb2bd0e49",
                       block_number: 6_535_159
                     },
                     %{
                       address_hash: "0xb7cffe2ac19b9d5705a24cbe14fef5663af905a6",
                       block_number: 6_535_159
                     },
                     %{
                       address_hash: "0xfa52274dd61e1643d2205169732f29114bc240b3",
                       block_number: 6_535_159
                     }
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 242_354_495_292_210,
                       gas_limit: 4_703_218,
                       gas_used: 1_009_480,
                       hash: "0x1f8cde8bd326702c49e065d56b08bdc82caa0c4820d914e27026c9c68ca1cf09",
                       miner_hash: "0x1c0fa194a9d3b44313dcd849f3c6be6ad270a0a4",
                       nonce: "0xafa5fc5c07f55ba5",
                       number: 6_535_159,
                       parent_hash: "0xd2cf6cf7a3d5455f450a2a3701995a7ad51f12010674883a6690cee337f75ffa",
                       size: 4052,
                       timestamp: DateTime.from_iso8601("2018-09-10 21:34:39Z") |> elem(1),
                       total_difficulty: 415_641_295_487_918_824_165
                     },
                     %{
                       consensus: true,
                       difficulty: 247_148_243_947_046,
                       gas_limit: 4_704_624,
                       gas_used: 363_000,
                       hash: "0xe16d3ce09c2f5bba53bb8a78268e70692f7d3401f654038f2733948f267819bf",
                       miner_hash: "0x1c0fa194a9d3b44313dcd849f3c6be6ad270a0a4",
                       nonce: "0xe7e0f2502c57af36",
                       number: 6_546_180,
                       parent_hash: "0x9fcef5db897c50c347bd62aaee3fd62f9430d7c5a6c1026645fd2d95bf84f77f",
                       size: 4135,
                       timestamp: DateTime.from_iso8601("2018-09-12 16:44:31Z") |> elem(1),
                       total_difficulty: 418_368_856_288_094_184_226
                     }
                   ]
                 },
                 broadcast: false,
                 transactions: %{
                   params: [
                     %{
                       block_hash: "0x1f8cde8bd326702c49e065d56b08bdc82caa0c4820d914e27026c9c68ca1cf09",
                       block_number: 6_535_159,
                       cumulative_gas_used: 978_227,
                       from_address_hash: "0xb7cffe2ac19b9d5705a24cbe14fef5663af905a6",
                       gas: 978_227,
                       gas_price: 99_000_000_000,
                       gas_used: 978_227,
                       hash: "0x1a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61",
                       index: 0,
                       input: "0x",
                       nonce: 1,
                       r:
                         33_589_694_337_999_451_585_110_289_972_555_130_664_768_096_048_542_148_916_928_040_955_524_640_045_158,
                       s:
                         42_310_749_137_599_445_408_044_732_541_966_181_996_695_356_587_068_481_874_121_265_172_051_825_560_665,
                       status: nil,
                       to_address_hash: nil,
                       transaction_hash: "0x1a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61",
                       transaction_index: 0,
                       v: 158,
                       value: 0
                     },
                     %{
                       block_hash: "0xe16d3ce09c2f5bba53bb8a78268e70692f7d3401f654038f2733948f267819bf",
                       block_number: 6_546_180,
                       cumulative_gas_used: 300_000,
                       from_address_hash: "0xb7cffe2ac19b9d5705a24cbe14fef5663af905a6",
                       gas: 300_000,
                       gas_price: 99_000_000_000,
                       gas_used: 300_000,
                       hash: "0xab349efbe1ddc6d85d84a993aa52bdaadce66e8ee166dd10013ce3f2a94ca724",
                       index: 0,
                       input: "0x",
                       nonce: 3,
                       r:
                         112_892_797_256_444_263_807_020_641_321_940_863_808_119_293_610_243_619_618_565_205_638_202_411_794_106,
                       s:
                         28_179_956_245_836_116_326_552_218_962_386_200_332_659_903_648_647_895_680_413_482_893_962_976_715_400,
                       status: nil,
                       to_address_hash: nil,
                       transaction_hash: "0xab349efbe1ddc6d85d84a993aa52bdaadce66e8ee166dd10013ce3f2a94ca724",
                       transaction_index: 0,
                       v: 157,
                       value: 0
                     }
                   ]
                 }
               })

      assert %Transaction{status: nil, error: nil} =
               Repo.get(Transaction, "0x1a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61")

      assert %Transaction{status: nil, error: nil} =
               Repo.get(Transaction, "0xab349efbe1ddc6d85d84a993aa52bdaadce66e8ee166dd10013ce3f2a94ca724")

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{
                       contract_code: "0x",
                       fetched_coin_balance_block_number: 6_535_159,
                       hash: "0xf606a51bd1be5e633f4170e302ea9f6f90a85c0f"
                     }
                   ]
                 },
                 internal_transactions: %{
                   params: [
                     %{
                       block_number: 6_535_159,
                       created_contract_address_hash: "0xf606a51bd1be5e633f4170e302ea9f6f90a85c0f",
                       created_contract_code: "0x",
                       from_address_hash: "0xb7cffe2ac19b9d5705a24cbe14fef5663af905a6",
                       gas: 710_459,
                       gas_used: 710_459,
                       index: 0,
                       init: "0x",
                       trace_address: [],
                       transaction_hash: "0x1a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61",
                       type: "create",
                       value: 0,
                       transaction_index: 0,
                       transaction_block_number: 35
                     },
                     %{
                       block_number: 6_546_180,
                       error: "Out of gas",
                       from_address_hash: "0xb7cffe2ac19b9d5705a24cbe14fef5663af905a6",
                       gas: 44376,
                       index: 0,
                       init: "0x",
                       trace_address: [],
                       transaction_hash: "0xab349efbe1ddc6d85d84a993aa52bdaadce66e8ee166dd10013ce3f2a94ca724",
                       type: "create",
                       value: 0,
                       transaction_index: 0,
                       transaction_block_number: 35
                     }
                   ],
                   with: :blockless_changeset
                 }
               })

      assert %Transaction{status: :ok, error: nil} =
               Repo.get(Transaction, "0x1a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61")

      assert %Transaction{status: :error, error: "Out of gas"} =
               Repo.get(Transaction, "0xab349efbe1ddc6d85d84a993aa52bdaadce66e8ee166dd10013ce3f2a94ca724")
    end

    test "uncles record their transaction indexes in transactions_forks" do
      miner_hash = address_hash()
      from_address_hash = address_hash()
      transaction_hash = transaction_hash()
      uncle_hash = block_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash},
                     %{hash: from_address_hash}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: false,
                       difficulty: 0,
                       gas_limit: 21_000,
                       gas_used: 21_000,
                       hash: uncle_hash,
                       miner_hash: miner_hash,
                       nonce: 0,
                       number: 0,
                       parent_hash: block_hash(),
                       size: 0,
                       timestamp: DateTime.utc_now(),
                       total_difficulty: 0
                     }
                   ]
                 },
                 transactions: %{
                   params: [
                     %{
                       block_hash: nil,
                       block_number: nil,
                       from_address_hash: from_address_hash,
                       gas: 21_000,
                       gas_price: 1,
                       hash: transaction_hash,
                       input: "0x",
                       nonce: 0,
                       r: 0,
                       s: 0,
                       v: 0,
                       value: 0
                     }
                   ]
                 },
                 transaction_forks: %{
                   params: [
                     %{
                       uncle_hash: uncle_hash,
                       index: 0,
                       hash: transaction_hash
                     }
                   ]
                 }
               })

      assert Repo.aggregate(Transaction.Fork, :count, :hash) == 1
    end

    test "reorganizations can switch blocks to non-consensus with new block taking the consensus spot for the number" do
      block_number = 0

      miner_hash_before = address_hash()
      from_address_hash_before = address_hash()
      block_hash_before = block_hash()
      difficulty_before = Decimal.new(0)
      gas_limit_before = Decimal.new(0)
      gas_used_before = Decimal.new(0)
      {:ok, nonce_before} = Hash.Nonce.cast(0)
      parent_hash_before = block_hash()
      size_before = 0
      timestamp_before = Timex.parse!("2019-01-01T01:00:00Z", "{ISO:Extended:Z}")
      total_difficulty_before = Decimal.new(0)

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_before},
                     %{hash: from_address_hash_before}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: difficulty_before,
                       gas_limit: gas_limit_before,
                       gas_used: gas_used_before,
                       hash: block_hash_before,
                       miner_hash: miner_hash_before,
                       nonce: nonce_before,
                       number: block_number,
                       parent_hash: parent_hash_before,
                       size: size_before,
                       timestamp: timestamp_before,
                       total_difficulty: total_difficulty_before
                     }
                   ]
                 }
               })

      %Block{consensus: true, number: ^block_number} = Repo.get(Block, block_hash_before)

      miner_hash_after = address_hash()
      from_address_hash_after = address_hash()
      block_hash_after = block_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_after},
                     %{hash: from_address_hash_after}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 1,
                       gas_limit: 1,
                       gas_used: 1,
                       hash: block_hash_after,
                       miner_hash: miner_hash_after,
                       nonce: 1,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 1,
                       timestamp: Timex.parse!("2019-01-01T02:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 1
                     }
                   ]
                 }
               })

      # new block grabs `consensus`
      assert %Block{
               consensus: true,
               difficulty: difficulty_after,
               gas_limit: gas_limit_after,
               gas_used: gas_used_after,
               nonce: nonce_after,
               number: ^block_number,
               parent_hash: parent_hash_after,
               size: size_after,
               timestamp: timestamp_after,
               total_difficulty: total_difficulty_after
             } = Repo.get(Block, block_hash_after)

      refute difficulty_after == difficulty_before
      refute gas_limit_after == gas_limit_before
      refute gas_used_after == gas_used_before
      refute nonce_after == nonce_before
      refute parent_hash_after == parent_hash_before
      refute size_after == size_before
      refute timestamp_after == timestamp_before
      refute total_difficulty_after == total_difficulty_before

      # only `consensus` changes in original block
      assert %Block{
               consensus: false,
               difficulty: ^difficulty_before,
               gas_limit: ^gas_limit_before,
               gas_used: ^gas_used_before,
               nonce: ^nonce_before,
               number: ^block_number,
               parent_hash: ^parent_hash_before,
               size: ^size_before,
               timestamp: timestamp,
               total_difficulty: ^total_difficulty_before
             } = Repo.get(Block, block_hash_before)

      assert DateTime.compare(timestamp, timestamp_before) == :eq
    end

    test "reorganizations nils transaction receipt fields for transactions that end up in non-consensus blocks" do
      block_number = 0

      miner_hash_before = address_hash()
      from_address_hash_before = address_hash()
      block_hash_before = block_hash()
      index_before = 0

      transaction_hash = transaction_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_before},
                     %{hash: from_address_hash_before}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 0,
                       gas_limit: 0,
                       gas_used: 0,
                       hash: block_hash_before,
                       miner_hash: miner_hash_before,
                       nonce: 0,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 0,
                       timestamp: Timex.parse!("2019-01-01T01:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 0
                     }
                   ]
                 },
                 transactions: %{
                   params: [
                     %{
                       block_hash: block_hash_before,
                       block_number: block_number,
                       from_address_hash: from_address_hash_before,
                       gas: 21_000,
                       gas_price: 1,
                       gas_used: 21_000,
                       cumulative_gas_used: 21_000,
                       hash: transaction_hash,
                       index: index_before,
                       input: "0x",
                       nonce: 0,
                       r: 0,
                       s: 0,
                       v: 0,
                       value: 0,
                       status: :ok
                     }
                   ]
                 }
               })

      %Block{consensus: true, number: ^block_number} = Repo.get(Block, block_hash_before)
      transaction_before = Repo.get!(Transaction, transaction_hash)

      refute transaction_before.block_hash == nil
      refute transaction_before.block_number == nil
      refute transaction_before.gas_used == nil
      refute transaction_before.cumulative_gas_used == nil
      refute transaction_before.index == nil
      refute transaction_before.status == nil

      miner_hash_after = address_hash()
      from_address_hash_after = address_hash()
      block_hash_after = block_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_after},
                     %{hash: from_address_hash_after}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 1,
                       gas_limit: 1,
                       gas_used: 1,
                       hash: block_hash_after,
                       miner_hash: miner_hash_after,
                       nonce: 1,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 1,
                       timestamp: Timex.parse!("2019-01-01T02:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 1
                     }
                   ]
                 }
               })

      transaction_after = Repo.get!(Transaction, transaction_hash)

      assert transaction_after.block_hash == nil
      assert transaction_after.block_number == nil
      assert transaction_after.gas_used == nil
      assert transaction_after.cumulative_gas_used == nil
      assert transaction_after.index == nil
      assert transaction_after.status == nil
    end

    test "reorganizations fork transactions that end up in non-consensus blocks" do
      block_number = 0

      miner_hash_before = address_hash()
      from_address_hash_before = address_hash()
      block_hash_before = block_hash()
      index_before = 0

      transaction_hash = transaction_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_before},
                     %{hash: from_address_hash_before}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 0,
                       gas_limit: 0,
                       gas_used: 0,
                       hash: block_hash_before,
                       miner_hash: miner_hash_before,
                       nonce: 0,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 0,
                       timestamp: Timex.parse!("2019-01-01T01:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 0
                     }
                   ]
                 },
                 transactions: %{
                   params: [
                     %{
                       block_hash: block_hash_before,
                       block_number: block_number,
                       from_address_hash: from_address_hash_before,
                       gas: 21_000,
                       gas_price: 1,
                       gas_used: 21_000,
                       cumulative_gas_used: 21_000,
                       hash: transaction_hash,
                       index: index_before,
                       input: "0x",
                       nonce: 0,
                       r: 0,
                       s: 0,
                       v: 0,
                       value: 0,
                       status: :ok
                     }
                   ]
                 }
               })

      %Block{consensus: true, number: ^block_number} = Repo.get(Block, block_hash_before)

      assert Repo.one!(from(transaction_fork in Transaction.Fork, select: fragment("COUNT(*)"))) == 0

      miner_hash_after = address_hash()
      from_address_hash_after = address_hash()
      block_hash_after = block_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_after},
                     %{hash: from_address_hash_after}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 1,
                       gas_limit: 1,
                       gas_used: 1,
                       hash: block_hash_after,
                       miner_hash: miner_hash_after,
                       nonce: 1,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 1,
                       timestamp: Timex.parse!("2019-01-01T02:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 1
                     }
                   ]
                 }
               })

      assert Repo.one!(from(transaction_fork in Transaction.Fork, select: fragment("COUNT(*)"))) == 1

      assert %Transaction.Fork{index: ^index_before} =
               Repo.one(
                 from(transaction_fork in Transaction.Fork,
                   where:
                     transaction_fork.uncle_hash == ^block_hash_before and transaction_fork.hash == ^transaction_hash
                 )
               )
    end

    test "timeouts can be overridden" do
      miner_hash = address_hash()
      uncle_miner_hash = address_hash()
      block_number = 0
      block_hash = block_hash()
      uncle_hash = block_hash()
      from_address_hash = address_hash()
      to_address_hash = address_hash()
      transaction_hash = transaction_hash()
      token_contract_address_hash = address_hash()

      assert {:ok,
              %{
                addresses: _,
                address_coin_balances: _,
                blocks: _,
                block_second_degree_relations: _,
                internal_transactions: _,
                logs: _,
                token_transfers: _,
                tokens: _,
                transactions: _,
                transaction_forks: _,
                address_token_balances: _
              }} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash},
                     %{hash: uncle_miner_hash},
                     %{hash: to_address_hash},
                     %{hash: from_address_hash},
                     %{hash: token_contract_address_hash}
                   ],
                   timeout: 1
                 },
                 address_coin_balances: %{
                   params: [
                     %{address_hash: miner_hash, block_number: block_number, value: nil},
                     %{address_hash: uncle_miner_hash, block_number: block_number, value: nil}
                   ],
                   timeout: 1
                 },
                 blocks: %{
                   params: [
                     params_for(:block, hash: block_hash, consensus: true, miner_hash: miner_hash, number: block_number),
                     params_for(:block,
                       hash: uncle_hash,
                       consensus: false,
                       miner_hash: uncle_miner_hash,
                       number: block_number
                     )
                   ],
                   timeout: 1
                 },
                 block_second_degree_relations: %{
                   params: [%{nephew_hash: block_hash, uncle_hash: uncle_hash, index: 0}],
                   timeout: 1
                 },
                 internal_transactions: %{
                   params: [
                     params_for(:internal_transaction,
                       transaction_hash: transaction_hash,
                       index: 0,
                       from_address_hash: from_address_hash,
                       to_address_hash: to_address_hash,
                       block_number: block_number,
                       transaction_index: 0
                     )
                   ],
                   timeout: 1,
                   with: :blockless_changeset
                 },
                 logs: %{
                   params: [
                     params_for(:log,
                       transaction_hash: transaction_hash,
                       address_hash: miner_hash,
                       block_hash: block_hash
                     )
                   ],
                   timeout: 1
                 },
                 token_transfers: %{
                   params: [
                     params_for(
                       :token_transfer,
                       block_hash: block_hash,
                       block_number: 35,
                       from_address_hash: from_address_hash,
                       to_address_hash: to_address_hash,
                       token_contract_address_hash: token_contract_address_hash,
                       transaction_hash: transaction_hash
                     )
                   ],
                   timeout: 1
                 },
                 tokens: %{
                   params: [params_for(:token, contract_address_hash: token_contract_address_hash)],
                   timeout: 1
                 },
                 transactions: %{
                   params: [
                     params_for(:transaction,
                       hash: transaction_hash,
                       block_hash: block_hash,
                       block_number: block_number,
                       index: 0,
                       from_address_hash: from_address_hash,
                       to_address_hash: to_address_hash,
                       gas_used: 0,
                       cumulative_gas_used: 0
                     )
                   ],
                   timeout: 1
                 },
                 transaction_forks: %{
                   params: [%{uncle_hash: uncle_hash, hash: transaction_hash, index: 0}],
                   timeout: 1
                 },
                 address_token_balances: %{
                   params: [
                     params_for(
                       :token_balance,
                       address_hash: to_address_hash,
                       token_contract_address_hash: token_contract_address_hash,
                       block_number: block_number
                     )
                   ],
                   timeout: 1
                 }
               })
    end

    # https://github.com/poanetwork/blockscout/pull/833#issuecomment-426102868 regression test
    test "a non-consensus block being added after a block with same number does not change the consensus block to non-consensus" do
      block_number = 0

      miner_hash_before = address_hash()
      from_address_hash_before = address_hash()
      block_hash_before = block_hash()
      difficulty_before = Decimal.new(0)
      gas_limit_before = Decimal.new(0)
      gas_used_before = Decimal.new(0)
      {:ok, nonce_before} = Hash.Nonce.cast(0)
      parent_hash_before = block_hash()
      size_before = 0
      timestamp_before = Timex.parse!("2019-01-01T01:00:00Z", "{ISO:Extended:Z}")
      total_difficulty_before = Decimal.new(0)

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_before},
                     %{hash: from_address_hash_before}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: difficulty_before,
                       gas_limit: gas_limit_before,
                       gas_used: gas_used_before,
                       hash: block_hash_before,
                       miner_hash: miner_hash_before,
                       nonce: nonce_before,
                       number: block_number,
                       parent_hash: parent_hash_before,
                       size: size_before,
                       timestamp: timestamp_before,
                       total_difficulty: total_difficulty_before
                     }
                   ]
                 }
               })

      %Block{consensus: true, number: ^block_number} = Repo.get(Block, block_hash_before)

      miner_hash_after = address_hash()
      from_address_hash_after = address_hash()
      block_hash_after = block_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_after},
                     %{hash: from_address_hash_after}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: false,
                       difficulty: 1,
                       gas_limit: 1,
                       gas_used: 1,
                       hash: block_hash_after,
                       miner_hash: miner_hash_after,
                       nonce: 1,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 1,
                       timestamp: Timex.parse!("2019-01-01T02:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 1
                     }
                   ]
                 }
               })

      # new block does not grab `consensus`
      assert %Block{
               consensus: false,
               difficulty: difficulty_after,
               gas_limit: gas_limit_after,
               gas_used: gas_used_after,
               nonce: nonce_after,
               number: ^block_number,
               parent_hash: parent_hash_after,
               size: size_after,
               timestamp: timestamp_after,
               total_difficulty: total_difficulty_after
             } = Repo.get(Block, block_hash_after)

      refute difficulty_after == difficulty_before
      refute gas_limit_after == gas_limit_before
      refute gas_used_after == gas_used_before
      refute nonce_after == nonce_before
      refute parent_hash_after == parent_hash_before
      refute size_after == size_before
      refute timestamp_after == timestamp_before
      refute total_difficulty_after == total_difficulty_before

      # nothing changes on the original consensus block
      assert %Block{
               consensus: true,
               difficulty: ^difficulty_before,
               gas_limit: ^gas_limit_before,
               gas_used: ^gas_used_before,
               nonce: ^nonce_before,
               number: ^block_number,
               parent_hash: ^parent_hash_before,
               size: ^size_before,
               timestamp: timestamp,
               total_difficulty: ^total_difficulty_before
             } = Repo.get(Block, block_hash_before)

      assert DateTime.compare(timestamp, timestamp_before) == :eq
    end

    # https://github.com/poanetwork/blockscout/issues/850 regression test
    test "derive_transaction_forks does not run when there are no blocks" do
      _pending_transaction = insert(:transaction)

      assert Import.all(%{
               blocks: %{
                 params: []
               }
             }) == {:ok, %{}}
    end

    # https://github.com/poanetwork/blockscout/issues/868 regression test
    test "errored transactions can be forked" do
      block_number = 0

      miner_hash_before = address_hash()
      from_address_hash_before = address_hash()
      to_address_hash_before = address_hash()
      block_hash_before = block_hash()
      index_before = 0
      error = "Reverted"

      transaction_hash = transaction_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_before},
                     %{hash: from_address_hash_before},
                     %{hash: to_address_hash_before}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 0,
                       gas_limit: 0,
                       gas_used: 0,
                       hash: block_hash_before,
                       miner_hash: miner_hash_before,
                       nonce: 0,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 0,
                       timestamp: Timex.parse!("2019-01-01T01:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 0
                     }
                   ]
                 },
                 transactions: %{
                   params: [
                     %{
                       block_hash: block_hash_before,
                       block_number: block_number,
                       error: error,
                       from_address_hash: from_address_hash_before,
                       to_address_hash: to_address_hash_before,
                       gas: 21_000,
                       gas_price: 1,
                       gas_used: 21_000,
                       cumulative_gas_used: 21_000,
                       hash: transaction_hash,
                       index: index_before,
                       input: "0x",
                       nonce: 0,
                       r: 0,
                       s: 0,
                       v: 0,
                       value: 0,
                       status: :error
                     }
                   ]
                 },
                 internal_transactions: %{
                   params: [
                     %{
                       transaction_hash: transaction_hash,
                       index: 0,
                       type: :call,
                       call_type: :call,
                       gas: 0,
                       from_address_hash: from_address_hash_before,
                       to_address_hash: to_address_hash_before,
                       trace_address: [],
                       value: 0,
                       input: "0x",
                       error: error,
                       block_number: block_number,
                       transaction_index: 0
                     }
                   ],
                   with: :blockless_changeset
                 }
               })

      %Block{consensus: true, number: ^block_number} = Repo.get(Block, block_hash_before)
      transaction_before = Repo.get!(Transaction, transaction_hash)

      refute transaction_before.block_hash == nil
      refute transaction_before.block_number == nil
      refute transaction_before.gas_used == nil
      refute transaction_before.cumulative_gas_used == nil
      refute transaction_before.index == nil
      refute transaction_before.status == nil

      miner_hash_after = address_hash()
      from_address_hash_after = address_hash()
      block_hash_after = block_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_after},
                     %{hash: from_address_hash_after}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 1,
                       gas_limit: 1,
                       gas_used: 1,
                       hash: block_hash_after,
                       miner_hash: miner_hash_after,
                       nonce: 1,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 1,
                       timestamp: Timex.parse!("2019-01-01T02:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 1
                     }
                   ]
                 }
               })

      transaction_after = Repo.get!(Transaction, transaction_hash)

      assert transaction_after.block_hash == nil
      assert transaction_after.block_number == nil
      assert transaction_after.gas_used == nil
      assert transaction_after.cumulative_gas_used == nil
      assert transaction_after.index == nil
      assert transaction_after.error == nil
      assert transaction_after.status == nil
    end

    test "address_token_balances and address_current_token_balances are deleted during reorgs" do
      %Block{number: block_number} = insert(:block, consensus: true)
      value_before = Decimal.new(1)

      %Address{hash: address_hash} = address = insert(:address)

      %Address.TokenBalance{
        address_hash: ^address_hash,
        token_contract_address_hash: token_contract_address_hash,
        block_number: ^block_number
      } = insert(:token_balance, address: address, block_number: block_number, value: value_before)

      %Address.CurrentTokenBalance{
        address_hash: ^address_hash,
        token_contract_address_hash: ^token_contract_address_hash,
        block_number: ^block_number
      } =
        insert(:address_current_token_balance,
          address: address,
          token_contract_address_hash: token_contract_address_hash,
          block_number: block_number,
          value: value_before
        )

      miner_hash_after = address_hash()
      from_address_hash_after = address_hash()
      block_hash_after = block_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_after},
                     %{hash: from_address_hash_after}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 1,
                       gas_limit: 1,
                       gas_used: 1,
                       hash: block_hash_after,
                       miner_hash: miner_hash_after,
                       nonce: 1,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 1,
                       timestamp: Timex.parse!("2019-01-01T02:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 1
                     }
                   ]
                 }
               })

      assert is_nil(
               Repo.get_by(Address.CurrentTokenBalance,
                 address_hash: address_hash,
                 token_contract_address_hash: token_contract_address_hash
               )
             )

      assert is_nil(
               Repo.get_by(Address.TokenBalance,
                 address_hash: address_hash,
                 token_contract_address_hash: token_contract_address_hash,
                 block_number: block_number
               )
             )
    end

    test "address_current_token_balances is derived during reorgs" do
      %Block{number: block_number} = insert(:block, consensus: true)
      previous_block_number = block_number - 1

      %Address.TokenBalance{
        address_hash: address_hash,
        token_contract_address_hash: token_contract_address_hash,
        value: previous_value,
        block_number: previous_block_number
      } = insert(:token_balance, block_number: previous_block_number)

      address = Repo.get(Address, address_hash)

      %Address.TokenBalance{
        address_hash: ^address_hash,
        token_contract_address_hash: token_contract_address_hash,
        value: current_value,
        block_number: ^block_number
      } =
        insert(:token_balance,
          address: address,
          token_contract_address_hash: token_contract_address_hash,
          block_number: block_number
        )

      refute current_value == previous_value

      %Address.CurrentTokenBalance{
        address_hash: ^address_hash,
        token_contract_address_hash: ^token_contract_address_hash,
        block_number: ^block_number
      } =
        insert(:address_current_token_balance,
          address: address,
          token_contract_address_hash: token_contract_address_hash,
          block_number: block_number,
          value: current_value
        )

      miner_hash_after = address_hash()
      from_address_hash_after = address_hash()
      block_hash_after = block_hash()

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: miner_hash_after},
                     %{hash: from_address_hash_after}
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 1,
                       gas_limit: 1,
                       gas_used: 1,
                       hash: block_hash_after,
                       miner_hash: miner_hash_after,
                       nonce: 1,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 1,
                       timestamp: Timex.parse!("2019-01-01T02:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 1
                     }
                   ]
                 }
               })

      assert %Address.CurrentTokenBalance{block_number: ^previous_block_number, value: ^previous_value} =
               Repo.get_by(Address.CurrentTokenBalance,
                 address_hash: address_hash,
                 token_contract_address_hash: token_contract_address_hash
               )

      assert is_nil(
               Repo.get_by(Address.TokenBalance,
                 address_hash: address_hash,
                 token_contract_address_hash: token_contract_address_hash,
                 block_number: block_number
               )
             )
    end

    test "address_token_balances and address_current_token_balances can be replaced during reorgs" do
      %Block{number: block_number} = insert(:block, consensus: true)
      value_before = Decimal.new(1)

      %Address{hash: address_hash} = address = insert(:address)

      %Address.TokenBalance{
        address_hash: ^address_hash,
        token_contract_address_hash: token_contract_address_hash,
        block_number: ^block_number
      } = insert(:token_balance, address: address, block_number: block_number, value: value_before)

      %Address.CurrentTokenBalance{
        address_hash: ^address_hash,
        token_contract_address_hash: ^token_contract_address_hash,
        block_number: ^block_number
      } =
        insert(:address_current_token_balance,
          address: address,
          token_contract_address_hash: token_contract_address_hash,
          block_number: block_number,
          value: value_before
        )

      miner_hash_after = address_hash()
      from_address_hash_after = address_hash()
      block_hash_after = block_hash()
      value_after = Decimal.add(value_before, 1)

      assert {:ok, _} =
               Import.all(%{
                 addresses: %{
                   params: [
                     %{hash: address_hash},
                     %{hash: token_contract_address_hash},
                     %{hash: miner_hash_after},
                     %{hash: from_address_hash_after}
                   ]
                 },
                 address_token_balances: %{
                   params: [
                     %{
                       address_hash: address_hash,
                       token_contract_address_hash: token_contract_address_hash,
                       block_number: block_number,
                       value: value_after
                     }
                   ]
                 },
                 address_current_token_balances: %{
                   params: [
                     %{
                       address_hash: address_hash,
                       token_contract_address_hash: token_contract_address_hash,
                       block_number: block_number,
                       value: value_after
                     }
                   ]
                 },
                 blocks: %{
                   params: [
                     %{
                       consensus: true,
                       difficulty: 1,
                       gas_limit: 1,
                       gas_used: 1,
                       hash: block_hash_after,
                       miner_hash: miner_hash_after,
                       nonce: 1,
                       number: block_number,
                       parent_hash: block_hash(),
                       size: 1,
                       timestamp: Timex.parse!("2019-01-01T02:00:00Z", "{ISO:Extended:Z}"),
                       total_difficulty: 1
                     }
                   ]
                 }
               })

      assert %Address.CurrentTokenBalance{value: ^value_after} =
               Repo.get_by(Address.CurrentTokenBalance,
                 address_hash: address_hash,
                 token_contract_address_hash: token_contract_address_hash
               )

      assert %Address.TokenBalance{value: ^value_after} =
               Repo.get_by(Address.TokenBalance,
                 address_hash: address_hash,
                 token_contract_address_hash: token_contract_address_hash,
                 block_number: block_number
               )
    end
  end
end
