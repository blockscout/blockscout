defmodule Explorer.Chain.ImportTest do
  use Explorer.DataCase

  alias Explorer.Chain

  alias Explorer.Chain.{
    Address,
    Address.TokenBalance,
    Block,
    Data,
    Log,
    Hash,
    Import,
    Token,
    TokenTransfer,
    Transaction
  }

  doctest Import

  describe "all/1" do
    @import_data %{
      blocks: %{
        params: [
          %{
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
        ]
      },
      broadcast: true,
      internal_transactions: %{
        params: [
          %{
            call_type: "call",
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_677_320,
            gas_used: 27770,
            index: 0,
            output: "0x",
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            trace_address: [],
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "call",
            value: 0
          }
        ]
      },
      logs: %{
        params: [
          %{
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
        ]
      },
      transactions: %{
        on_conflict: :replace_all,
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
        ]
      },
      addresses: %{
        params: [
          %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"},
          %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"},
          %{hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d"}
        ]
      },
      tokens: %{
        on_conflict: :nothing,
        params: [
          %{
            contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            type: "ERC-20"
          }
        ]
      },
      token_transfers: %{
        params: [
          %{
            amount: Decimal.new(1_000_000_000_000_000_000),
            block_number: 37,
            log_index: 0,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            to_address_hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
          }
        ]
      }
    }

    test "with valid data" do
      difficulty = Decimal.new(340_282_366_920_938_463_463_374_607_431_768_211_454)
      total_difficulty = Decimal.new(12_590_447_576_074_723_148_144_860_474_975_121_280_509)
      token_transfer_amount = Decimal.new(1_000_000_000_000_000_000)

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
                    gas_limit: 6_946_336,
                    gas_used: 50450,
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
                  %Hash{
                    byte_count: 32,
                    bytes:
                      <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                        101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
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
          ]
        },
        tokens: %{
          on_conflict: :nothing,
          params: [
            %{
              contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              type: "ERC-20"
            }
          ]
        },
        token_balances: %{
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
          ]
        }
      }

      Import.all(params)

      count = Explorer.Repo.one(Ecto.Query.from(t in TokenBalance, select: count(t.id)))

      assert 3 == count
    end

    test "with empty map" do
      assert {:ok, %{}} == Import.all(%{})
    end

    test "publishes data to subscribers on insert" do
      Chain.subscribe_to_events(:logs)
      Import.all(@import_data)
      assert_received {:chain_event, :logs, [%Log{}]}
    end

    test "with invalid data" do
      invalid_transaction =
        @import_data
        |> Map.get(:internal_transactions)
        |> Map.get(:params)
        |> Enum.at(0)
        |> Map.delete(:call_type)

      invalid_import_data = put_in(@import_data, [:internal_transactions, :params], [invalid_transaction])

      assert {:error, [changeset]} = Import.all(invalid_import_data)
      assert changeset_errors(changeset)[:call_type] == ["can't be blank"]
    end

    test "publishes addresses with updated fetched_coin_balance data to subscribers on insert" do
      Chain.subscribe_to_events(:addresses)
      Import.all(@import_data)
      assert_received {:chain_event, :addresses, [%Address{}, %Address{}, %Address{}]}
    end

    test "publishes block data to subscribers on insert" do
      Chain.subscribe_to_events(:blocks)
      Import.all(@import_data)
      assert_received {:chain_event, :blocks, [%Block{}]}
    end

    test "publishes log data to subscribers on insert" do
      Chain.subscribe_to_events(:logs)
      Import.all(@import_data)
      assert_received {:chain_event, :logs, [%Log{}]}
    end

    test "publishes transaction hashes data to subscribers on insert" do
      Chain.subscribe_to_events(:transactions)
      Import.all(@import_data)
      assert_received {:chain_event, :transactions, [%Hash{}]}
    end

    test "does not broadcast if broadcast option is false" do
      non_broadcast_data = Map.merge(@import_data, %{broadcast: false})

      Chain.subscribe_to_events(:logs)
      Import.all(non_broadcast_data)
      refute_received {:chain_event, :logs, [%Log{}]}
    end

    test "updates address with contract code" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      address_hash = "0x1c494fa496f1cfd918b5ff190835af3aaf60987e"
      insert(:address, hash: address_hash)

      from_address_hash = "0x8cc2e4b51b4340cb3727cffe3f1878756e732cee"
      from_address = insert(:address, hash: from_address_hash)

      transaction_string_hash = "0x0705ea0a5b997d9aafd5c531e016d9aabe3297a28c0bd4ef005fe6ea329d301b"
      insert(:transaction, from_address: from_address, hash: transaction_string_hash)

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
              value: 0
            }
          ]
        }
      }

      assert {:ok, _} = Import.all(options)

      address = Explorer.Repo.get(Address, address_hash)

      assert address.contract_code != smart_contract_bytecode
    end

    test "with internal_transactions updates Transaction internal_transactions_indexed_at" do
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

      options = %{
        addresses: %{
          params: [
            %{hash: from_address_hash},
            %{hash: to_address_hash}
          ]
        },
        transactions: %{
          params: [
            %{
              from_address_hash: from_address_hash,
              gas: 4_677_320,
              gas_price: 1,
              hash: transaction_hash,
              input: "0x",
              nonce: 0,
              r: 0,
              s: 0,
              v: 0,
              value: 0
            }
          ],
          on_conflict: :replace_all
        },
        internal_transactions: %{
          params: [
            %{
              block_number: 35,
              call_type: "call",
              from_address_hash: from_address_hash,
              gas: 4_677_320,
              gas_used: 27770,
              index: 0,
              output: "0x",
              to_address_hash: to_address_hash,
              trace_address: [],
              transaction_hash: transaction_hash,
              type: "call",
              value: 0
            }
          ]
        }
      }

      refute Enum.any?(options[:transactions][:params], &Map.has_key?(&1, :internal_transactions_indexed_at))

      assert {:ok, _} = Import.all(options)

      transaction = Explorer.Repo.get(Transaction, transaction_hash)

      refute transaction.internal_transactions_indexed_at == nil
    end

    test "when the transaction has no to_address and an internal transaction with type create it populates the denormalized created_contract_address_hash" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
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
        transactions: %{
          params: [
            %{
              from_address_hash: from_address_hash,
              gas: 4_677_320,
              gas_price: 1,
              hash: transaction_hash,
              input: "0x",
              nonce: 0,
              r: 0,
              s: 0,
              v: 0,
              value: 0
            }
          ],
          on_conflict: :replace_all
        },
        internal_transactions: %{
          params: [
            %{
              block_number: 35,
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
              value: 0
            }
          ]
        }
      }

      assert {:ok, _} = Import.all(options)

      transaction = Explorer.Repo.get(Transaction, transaction_hash)

      assert {:ok, transaction.created_contract_address_hash} ==
               Chain.string_to_address_hash(created_contract_address_hash)
    end

    test "when the transaction has a to_address and an internal transaction with type create it does not populates the denormalized created_contract_address_hash" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      to_address_hash = "0xf7ddc5c7a2d2f0d7a9798459c0104fdf5e9a7bbb"
      created_contract_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

      options = %{
        addresses: %{
          params: [
            %{hash: from_address_hash},
            %{
              contract_code: smart_contract_bytecode,
              hash: created_contract_address_hash
            },
            %{hash: to_address_hash}
          ]
        },
        transactions: %{
          params: [
            %{
              from_address_hash: from_address_hash,
              gas: 4_677_320,
              gas_price: 1,
              hash: transaction_hash,
              input: "0x",
              nonce: 0,
              r: 0,
              s: 0,
              to_address_hash: to_address_hash,
              v: 0,
              value: 0
            }
          ],
          on_conflict: :replace_all
        },
        internal_transactions: %{
          params: [
            %{
              block_number: 35,
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
              to_address_hash: to_address_hash,
              trace_address: [],
              transaction_hash: transaction_hash,
              type: "create",
              value: 0
            }
          ]
        }
      }

      assert {:ok, _} = Import.all(options)

      transaction = Explorer.Repo.get(Transaction, transaction_hash)

      assert transaction.created_contract_address_hash == nil
    end
  end
end
