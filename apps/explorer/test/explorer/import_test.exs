defmodule Explorer.Chain.ImportTest do
  use Explorer.DataCase

  alias Explorer.Chain.Import

  doctest Import

  describe "all/1" do
    test "updates address with contract code" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      address_hash = "0x1c494fa496f1cfd918b5ff190835af3aaf60987e"
      insert(:address, hash: address_hash)

      from_address_hash = "0x8cc2e4b51b4340cb3727cffe3f1878756e732cee"
      from_address = insert(:address, hash: from_address_hash)

      transaction_string_hash = "0x0705ea0a5b997d9aafd5c531e016d9aabe3297a28c0bd4ef005fe6ea329d301b"
      insert(:transaction, from_address: from_address, hash: transaction_string_hash)

      options = [
        addresses: [
          params: [
            %{
              contract_code: smart_contract_bytecode,
              hash: address_hash
            }
          ]
        ],
        internal_transactions: [
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
        ]
      ]

      assert {:ok, _} = Import.all(options)

      address = Explorer.Repo.one(from(address in Explorer.Chain.Address, where: address.hash == ^address_hash))

      assert address.contract_code != nil
    end

    test "with internal_transactions updates Transaction internal_transactions_indexed_at" do
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      to_address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      transaction_hash = "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

      options = [
        addresses: [
          params: [
            %{hash: from_address_hash},
            %{hash: to_address_hash}
          ]
        ],
        transactions: [
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
        ],
        internal_transactions: [
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
        ]
      ]

      refute Enum.any?(options[:transactions][:params], &Map.has_key?(&1, :internal_transactions_indexed_at))

      assert {:ok, _} = Import.all(options)

      transaction =
        Explorer.Repo.one(from(transaction in Explorer.Chain.Transaction, where: transaction.hash == ^transaction_hash))

      refute transaction.internal_transactions_indexed_at == nil
    end
  end
end
