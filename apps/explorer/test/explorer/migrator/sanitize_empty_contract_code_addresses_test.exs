defmodule Explorer.Migrator.SanitizeEmptyContractCodeAddressesTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Address
  alias Explorer.Migrator.{SanitizeEmptyContractCodeAddresses, MigrationStatus}
  alias Explorer.Repo

  describe "sanitize addresses with empty contract code" do
    test "sets contract_code to '0x' for addresses that originally had nil code" do
      # Create addresses with empty contract code "0x" that should be updated
      addresses_to_update =
        Enum.map(1..5, fn _ ->
          address = insert(:address, contract_code: nil)

          # Associate each address with a transaction as created_contract_address_hash
          insert(:transaction,
            created_contract_address_hash: address.hash,
            status: :error
          )

          address
        end)

      # Create addresses with non-empty contract code (shouldn't be updated)
      addresses_with_code =
        Enum.map(1..3, fn _ ->
          address = insert(:address, contract_code: "0x1234")
          insert(:transaction, created_contract_address_hash: address.hash)
          address
        end)

      addresses_with_not_yet_fetched_bytecode =
        Enum.map(1..3, fn _ ->
          address = insert(:address, contract_code: nil)
          block = insert(:block)

          insert(:transaction,
            block_hash: block.hash,
            block_number: block.number,
            created_contract_address_hash: address.hash,
            cumulative_gas_used: 21000,
            gas_used: 21000,
            index: 0,
            status: :ok
          )

          address
        end)

      # Verify initial state
      assert MigrationStatus.get_status("sanitize_empty_contract_code_addresses") == nil

      # Run the migration
      SanitizeEmptyContractCodeAddresses.start_link([])
      Process.sleep(100)

      # Check that addresses with `nil` and associated transactions had their contract_code set to "0x"
      for address <- addresses_to_update do
        updated_address = Repo.get(Address, address.hash)
        assert to_string(updated_address.contract_code) == "0x"
      end

      # Check that addresses with actual contract code weren't changed
      for address <- addresses_with_code do
        unchanged_address = Repo.get(Address, address.hash)
        assert to_string(unchanged_address.contract_code) == "0x1234"
      end

      # Check that addresses with not yet fetched bytecode weren't changed
      for address <- addresses_with_not_yet_fetched_bytecode do
        unchanged_address = Repo.get(Address, address.hash)
        assert unchanged_address.contract_code == nil
      end

      # Check migration status
      assert MigrationStatus.get_status("sanitize_empty_contract_code_addresses") == "completed"
    end
  end
end
