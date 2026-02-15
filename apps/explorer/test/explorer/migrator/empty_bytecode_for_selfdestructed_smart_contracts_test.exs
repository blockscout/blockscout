defmodule Explorer.Migrator.EmptyBytecodeForSelfdestructedSmartContractsTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{Address, Data}
  alias Explorer.Migrator.EmptyBytecodeForSelfdestructedSmartContracts
  alias Explorer.Repo

  describe "migration_name/0" do
    test "returns the correct migration name" do
      assert EmptyBytecodeForSelfdestructedSmartContracts.migration_name() ==
               "empty_bytecode_for_selfdestructed_smart_contracts"
    end
  end

  describe "update_batch/1" do
    test "returns {:ok, []} when block_numbers is empty" do
      assert {:ok, []} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([])
    end

    test "returns {:ok, []} when no selfdestruct transactions exist in blocks" do
      block = insert(:block, number: 100)
      transaction = insert(:transaction) |> with_block(block)

      insert(:internal_transaction,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        index: 0,
        transaction_index: transaction.index,
        type: :call
      )

      assert {:ok, []} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([block.number])
    end

    test "empties contract_code for address with selfdestruct transaction" do
      block = insert(:block, number: 200)
      contract_code = %Data{bytes: <<1, 2, 3, 4, 5>>}

      # Create a contract with bytecode
      contract_address = insert(:address, contract_code: contract_code)
      recipient_address = insert(:address)

      # Create a transaction with selfdestruct
      transaction = insert(:transaction) |> with_block(block)

      insert(:internal_transaction,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        index: 0,
        transaction_index: transaction.index,
        type: :selfdestruct,
        from_address: contract_address,
        to_address: recipient_address,
        gas: nil
      )

      assert {:ok, 1} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([block.number])

      # Verify contract_code is now empty
      updated_address = Repo.get(Address, contract_address.hash)
      assert updated_address.contract_code == %Data{bytes: <<>>}
    end

    test "does NOT empty contract_code when contract created and selfdestructed in same transaction" do
      block = insert(:block, number: 300)
      contract_code = %Data{bytes: <<1, 2, 3, 4, 5>>}

      # Create a contract with bytecode
      contract_address = insert(:address, contract_code: contract_code)
      recipient_address = insert(:address)

      # Create a transaction with both create and selfdestruct
      transaction = insert(:transaction) |> with_block(block)

      insert(:internal_transaction_create,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        index: 0,
        transaction_index: transaction.index,
        created_contract_address: contract_address,
        created_contract_code: contract_code
      )

      insert(:internal_transaction,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        index: 1,
        transaction_index: transaction.index,
        type: :selfdestruct,
        from_address: contract_address,
        to_address: recipient_address,
        gas: nil
      )

      assert {:ok, []} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([block.number])

      # Verify contract_code is still present
      updated_address = Repo.get(Address, contract_address.hash)
      assert updated_address.contract_code == contract_code
    end

    test "does NOT empty contract_code when contract created with create2 and selfdestructed in same transaction" do
      block = insert(:block, number: 350)
      contract_code = %Data{bytes: <<1, 2, 3, 4, 5>>}

      # Create a contract with bytecode
      contract_address = insert(:address, contract_code: contract_code)
      recipient_address = insert(:address)

      # Create a transaction with both create2 and selfdestruct
      transaction = insert(:transaction) |> with_block(block)

      insert(:internal_transaction_create,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        index: 0,
        transaction_index: transaction.index,
        type: :create2,
        created_contract_address: contract_address,
        created_contract_code: contract_code
      )

      insert(:internal_transaction,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        index: 1,
        transaction_index: transaction.index,
        type: :selfdestruct,
        from_address: contract_address,
        to_address: recipient_address,
        gas: nil
      )

      assert {:ok, []} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([block.number])

      # Verify contract_code is still present
      updated_address = Repo.get(Address, contract_address.hash)
      assert updated_address.contract_code == contract_code
    end

    test "handles multiple selfdestruct transactions in same block" do
      block = insert(:block, number: 400)
      contract_code_1 = %Data{bytes: <<1, 2, 3>>}
      contract_code_2 = %Data{bytes: <<4, 5, 6>>}

      # Create two contracts with bytecode
      contract_address_1 = insert(:address, contract_code: contract_code_1)
      contract_address_2 = insert(:address, contract_code: contract_code_2)
      recipient_address_1 = insert(:address)
      recipient_address_2 = insert(:address)

      # Create separate transactions for each selfdestruct
      transaction_1 = insert(:transaction, gas: 21_000) |> with_block(block)
      transaction_2 = insert(:transaction, gas: 22_000) |> with_block(block)

      insert(:internal_transaction,
        transaction: transaction_1,
        block_hash: transaction_1.block_hash,
        block_number: transaction_1.block_number,
        index: 0,
        transaction_index: transaction_1.index,
        type: :selfdestruct,
        from_address: contract_address_1,
        to_address: recipient_address_1,
        gas: nil
      )

      insert(:internal_transaction,
        transaction: transaction_2,
        block_hash: transaction_2.block_hash,
        block_number: transaction_2.block_number,
        index: 0,
        transaction_index: transaction_2.index,
        type: :selfdestruct,
        from_address: contract_address_2,
        to_address: recipient_address_2,
        gas: nil
      )

      assert {:ok, 2} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([block.number])

      # Verify both contracts have empty contract_code
      updated_address_1 = Repo.get(Address, contract_address_1.hash)
      updated_address_2 = Repo.get(Address, contract_address_2.hash)
      assert updated_address_1.contract_code == %Data{bytes: <<>>}
      assert updated_address_2.contract_code == %Data{bytes: <<>>}
    end

    test "does NOT update address that already has empty contract_code" do
      block = insert(:block, number: 500)
      empty_contract_code = %Data{bytes: <<>>}

      # Create a contract with already empty bytecode
      contract_address = insert(:address, contract_code: empty_contract_code)
      recipient_address = insert(:address)

      # Create a transaction with selfdestruct
      transaction = insert(:transaction) |> with_block(block)

      insert(:internal_transaction,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        index: 0,
        transaction_index: transaction.index,
        type: :selfdestruct,
        from_address: contract_address,
        to_address: recipient_address,
        gas: nil
      )

      assert {:ok, 0} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([block.number])

      # Verify contract_code remains empty (no update occurred)
      updated_address = Repo.get(Address, contract_address.hash)
      assert updated_address.contract_code == empty_contract_code
    end

    test "does NOT update address with nil contract_code" do
      block = insert(:block, number: 550)

      # Create a regular address (not a contract, contract_code is nil)
      address = insert(:address, contract_code: nil)
      recipient_address = insert(:address)

      # Create a transaction with selfdestruct
      transaction = insert(:transaction) |> with_block(block)

      insert(:internal_transaction,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        index: 0,
        transaction_index: transaction.index,
        type: :selfdestruct,
        from_address: address,
        to_address: recipient_address,
        gas: nil
      )

      assert {:ok, 0} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([block.number])

      # Verify contract_code remains nil
      updated_address = Repo.get(Address, address.hash)
      assert updated_address.contract_code == nil
    end

    test "handles multiple blocks in one batch" do
      block_1 = insert(:block, number: 600)
      block_2 = insert(:block, number: 601)
      contract_code_1 = %Data{bytes: <<1, 2, 3>>}
      contract_code_2 = %Data{bytes: <<4, 5, 6>>}

      # Create two contracts with bytecode
      contract_address_1 = insert(:address, contract_code: contract_code_1)
      contract_address_2 = insert(:address, contract_code: contract_code_2)
      recipient_address_1 = insert(:address)
      recipient_address_2 = insert(:address)

      # Create selfdestruct in first block
      transaction_1 = insert(:transaction, gas: 21_000) |> with_block(block_1)

      insert(:internal_transaction,
        transaction: transaction_1,
        block_hash: transaction_1.block_hash,
        block_number: transaction_1.block_number,
        index: 0,
        transaction_index: transaction_1.index,
        type: :selfdestruct,
        from_address: contract_address_1,
        to_address: recipient_address_1,
        gas: nil
      )

      # Create selfdestruct in second block
      transaction_2 = insert(:transaction, gas: 22_000) |> with_block(block_2)

      insert(:internal_transaction,
        transaction: transaction_2,
        block_hash: transaction_2.block_hash,
        block_number: transaction_2.block_number,
        index: 0,
        transaction_index: transaction_2.index,
        type: :selfdestruct,
        from_address: contract_address_2,
        to_address: recipient_address_2,
        gas: nil
      )

      assert {:ok, 2} =
               EmptyBytecodeForSelfdestructedSmartContracts.update_batch([
                 block_1.number,
                 block_2.number
               ])

      # Verify both contracts have empty contract_code
      updated_address_1 = Repo.get(Address, contract_address_1.hash)
      updated_address_2 = Repo.get(Address, contract_address_2.hash)
      assert updated_address_1.contract_code == %Data{bytes: <<>>}
      assert updated_address_2.contract_code == %Data{bytes: <<>>}
    end

    test "handles mixed scenario: one should empty, one should not" do
      block = insert(:block, number: 700)
      contract_code_1 = %Data{bytes: <<1, 2, 3>>}
      contract_code_2 = %Data{bytes: <<4, 5, 6>>}

      # Create two contracts
      contract_address_1 = insert(:address, contract_code: contract_code_1)
      contract_address_2 = insert(:address, contract_code: contract_code_2)
      recipient_address_1 = insert(:address)
      recipient_address_2 = insert(:address)

      # First transaction: selfdestruct without create (should empty)
      transaction_1 = insert(:transaction, gas: 21_000) |> with_block(block)

      insert(:internal_transaction,
        transaction_hash: transaction_1.hash,
        block_hash: transaction_1.block_hash,
        block_number: transaction_1.block_number,
        index: 0,
        transaction_index: transaction_1.index,
        type: :selfdestruct,
        from_address: contract_address_1,
        to_address: recipient_address_1,
        gas: nil
      )

      # Second transaction: create + selfdestruct (should NOT empty)
      transaction_2 = insert(:transaction, gas: 22_000) |> with_block(block)

      insert(:internal_transaction_create,
        transaction_hash: transaction_2.hash,
        block_hash: transaction_2.block_hash,
        block_number: transaction_2.block_number,
        index: 0,
        transaction_index: transaction_2.index,
        created_contract_address: contract_address_2,
        created_contract_code: contract_code_2
      )

      insert(:internal_transaction,
        transaction_hash: transaction_2.hash,
        block_hash: transaction_2.block_hash,
        block_number: transaction_2.block_number,
        index: 1,
        transaction_index: transaction_2.index,
        type: :selfdestruct,
        from_address: contract_address_2,
        to_address: recipient_address_2,
        gas: nil
      )

      assert {:ok, 1} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([block.number])

      # Verify first contract is empty, second is not
      updated_address_1 = Repo.get(Address, contract_address_1.hash)
      updated_address_2 = Repo.get(Address, contract_address_2.hash)
      assert updated_address_1.contract_code == %Data{bytes: <<>>}
      assert updated_address_2.contract_code == contract_code_2
    end

    test "handles same contract selfdestructed multiple times in different transactions" do
      block = insert(:block, number: 800)
      contract_code = %Data{bytes: <<1, 2, 3, 4, 5>>}

      # Create a contract with bytecode
      contract_address = insert(:address, contract_code: contract_code)
      recipient_address = insert(:address)

      # Create two different transactions with selfdestruct for the same address
      transaction_1 = insert(:transaction, gas: 21_000) |> with_block(block)
      transaction_2 = insert(:transaction, gas: 22_000) |> with_block(block)

      insert(:internal_transaction,
        transaction_hash: transaction_1.hash,
        block_hash: transaction_1.block_hash,
        block_number: transaction_1.block_number,
        index: 0,
        transaction_index: transaction_1.index,
        type: :selfdestruct,
        from_address: contract_address,
        to_address: recipient_address,
        gas: nil
      )

      insert(:internal_transaction,
        transaction_hash: transaction_2.hash,
        block_hash: transaction_2.block_hash,
        block_number: transaction_2.block_number,
        index: 0,
        transaction_index: transaction_2.index,
        type: :selfdestruct,
        from_address: contract_address,
        to_address: recipient_address,
        gas: nil
      )

      # Should still only update once since it's the same address
      assert {:ok, 1} = EmptyBytecodeForSelfdestructedSmartContracts.update_batch([block.number])

      # Verify contract_code is empty
      updated_address = Repo.get(Address, contract_address.hash)
      assert updated_address.contract_code == %Data{bytes: <<>>}
    end
  end

  describe "last_unprocessed_identifiers/1" do
    test "returns empty list when min_block_number is negative" do
      state = %{"min_block_number" => -1}

      assert {[], %{"min_block_number" => -1}} =
               EmptyBytecodeForSelfdestructedSmartContracts.last_unprocessed_identifiers(state)
    end

    test "returns block numbers in descending order" do
      state = %{"min_block_number" => 100}

      {block_numbers, new_state} =
        EmptyBytecodeForSelfdestructedSmartContracts.last_unprocessed_identifiers(state)

      # Should return blocks in descending order
      assert length(block_numbers) > 0
      assert block_numbers == Enum.sort(block_numbers, :desc)
      assert hd(block_numbers) == 100
      assert new_state["min_block_number"] < 100
    end

    test "handles blocks down to zero" do
      # Set a small number to test boundary
      state = %{"min_block_number" => 5}

      {block_numbers, new_state} =
        EmptyBytecodeForSelfdestructedSmartContracts.last_unprocessed_identifiers(state)

      assert length(block_numbers) > 0
      assert Enum.min(block_numbers) >= 0
      assert new_state["min_block_number"] <= 0
    end
  end

  describe "update_cache/0" do
    test "returns :ok" do
      assert :ok = EmptyBytecodeForSelfdestructedSmartContracts.update_cache()
    end
  end
end
