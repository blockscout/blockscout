defmodule Explorer.Indexer.BlockFetcher.AddressExtractionTest do
  use Explorer.DataCase, async: true

  alias Explorer.Indexer.BlockFetcher.AddressExtraction

  describe "extract_addresses/1" do
    test "returns all hashes entities data in a list" do
      block = %{miner_hash: gen_hash()}

      internal_transaction = %{
        from_address_hash: gen_hash(),
        to_address_hash: gen_hash(),
        created_contract_address_hash: gen_hash(),
        created_contract_code: "code"
      }

      transaction = %{
        from_address_hash: gen_hash(),
        to_address_hash: gen_hash()
      }

      log = %{address_hash: gen_hash()}

      blockchain_data = %{
        blocks: [block],
        internal_transactions: [internal_transaction],
        transactions: [transaction],
        logs: [log]
      }

      assert AddressExtraction.extract_addresses(blockchain_data) == [
               %{hash: block.miner_hash},
               %{hash: internal_transaction.from_address_hash},
               %{hash: internal_transaction.to_address_hash},
               %{
                 hash: internal_transaction.created_contract_address_hash,
                 contract_code: internal_transaction.created_contract_code
               },
               %{hash: transaction.from_address_hash},
               %{hash: transaction.to_address_hash},
               %{hash: log.address_hash}
             ]
    end

    test "returns empty list with empty data" do
      empty_blockchain_data = %{
        blocks: [],
        transactions: [],
        internal_transactions: [],
        logs: []
      }

      addresses = AddressExtraction.extract_addresses(empty_blockchain_data)

      assert Enum.empty?(addresses)
    end

    test "addresses get merged when they're duplicated by their hash" do
      hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"

      blockchain_data = %{
        blocks: [%{miner_hash: hash}],
        transactions: [%{from_address_hash: hash}],
        internal_transactions: [
          %{
            created_contract_address_hash: hash,
            created_contract_code: "code"
          }
        ]
      }

      assert AddressExtraction.extract_addresses(blockchain_data) ==
               [
                 %{hash: hash, contract_code: "code"}
               ]
    end

    test "only entities data defined in @entity_to_address_map are collected" do
      blockchain_data = %{
        blocks: [%{miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"}],
        unkown_entity: [%{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}]
      }

      assert AddressExtraction.extract_addresses(blockchain_data) == [
               %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"}
             ]
    end

    test "returns an empty list when there isn't a recognized entity" do
      addresses = AddressExtraction.extract_addresses(%{})

      assert Enum.empty?(addresses)
    end
  end

  describe "extract_addresses_from_collection/2" do
    test "returns all matched addresses" do
      fields_map = [
        %{from: :field_1, to: :hash},
        %{from: :field_2, to: :hash}
      ]

      items = [
        %{field_1: "hash1", field_2: "hash2"},
        %{field_1: "hash1", field_2: "hash3"}
      ]

      assert AddressExtraction.extract_addresses_from_collection(items, fields_map) == [
               %{hash: "hash1"},
               %{hash: "hash2"},
               %{hash: "hash1"},
               %{hash: "hash3"}
             ]
    end
  end

  describe "extract_addresses_from_item/2" do
    test "only fields specified in the fields map are fetched" do
      fields_map = [
        %{from: :field_1, to: :hash}
      ]

      item = %{field_1: "hash1", field_2: "hash2"}

      response = AddressExtraction.extract_addresses_from_item(item, fields_map)

      assert response == [%{hash: "hash1"}]
    end

    test "attributes of the same item defined separately in the fields map fetches different addresses" do
      fields_map = [
        %{from: :field_1, to: :hash},
        %{from: :field_2, to: :hash}
      ]

      item = %{field_1: "hash1", field_2: "hash2"}

      response = AddressExtraction.extract_addresses_from_item(item, fields_map)

      assert response == [%{hash: "hash1"}, %{hash: "hash2"}]
    end

    test "a list of attributes in the fields map references the same address" do
      fields_map = [
        %{from: :field_1, to: :hash},
        [
          %{from: :field_2, to: :hash},
          %{from: :field_2_code, to: :code}
        ]
      ]

      data = %{field_1: "hash1", field_2: "hash2", field_2_code: "code"}

      response =
        AddressExtraction.extract_addresses_from_item(
          data,
          fields_map
        )

      assert response == [
               %{hash: "hash1"},
               %{code: "code", hash: "hash2"}
             ]
    end
  end

  defp gen_hash() do
    Explorer.Chain.Hash.to_string(Explorer.Factory.address_hash())
  end
end
