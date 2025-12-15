defmodule Explorer.Chain.Import.Runner.FheOperationsTest do
  use Explorer.DataCase

  import Mox

  alias Ecto.Multi
  alias Explorer.Chain.{Block, FheOperation, Hash, Transaction}
  alias Explorer.Chain.Import.Runner.FheOperations
  alias Explorer.Repo

  setup :verify_on_exit!
  setup :set_mox_global

  describe "run/3" do
    test "inserts FHE operations successfully" do
      transaction = insert(:transaction) |> with_block()
      block = transaction.block
      caller = insert(:address)

      changes_list = [
        %{
          transaction_hash: transaction.hash,
          log_index: 1,
          block_hash: block.hash,
          block_number: block.number,
          operation: "FheAdd",
          operation_type: "arithmetic",
          fhe_type: "Uint8",
          is_scalar: false,
          hcu_cost: 100,
          hcu_depth: 1,
          caller: caller.hash,
          result_handle: <<1::256>>,
          input_handles: %{"lhs" => "0x00", "rhs" => "0x00"}
        }
      ]

      timestamp = DateTime.utc_now()
      options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

      # Multi.run unwraps the {:ok, value} tuple
      assert {:ok, %{insert_fhe_operations: [inserted]}} =
               Multi.new()
               |> FheOperations.run(changes_list, options)
               |> Repo.transaction()

      assert inserted.transaction_hash == transaction.hash
      assert inserted.log_index == 1
      assert inserted.operation == "FheAdd"
    end

    test "handles empty changes list" do
      timestamp = DateTime.utc_now()
      options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

      # Multi.run unwraps the {:ok, value} tuple, so we get just the value
      assert {:ok, %{insert_fhe_operations: []}} =
               Multi.new()
               |> FheOperations.run([], options)
               |> Repo.transaction()
    end

    test "handles conflict resolution on duplicate operations" do
      transaction = insert(:transaction) |> with_block()
      block = transaction.block

      # Insert first operation
      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 1,
        block_hash: block.hash,
        block_number: block.number,
        operation: "FheAdd",
        hcu_cost: 100
      )

      # Try to insert same operation with different data
      changes_list = [
        %{
          transaction_hash: transaction.hash,
          log_index: 1,
          block_hash: block.hash,
          block_number: block.number,
          operation: "FheMul",
          operation_type: "arithmetic",
          fhe_type: "Uint8",
          is_scalar: false,
          hcu_cost: 200,
          hcu_depth: 1,
          caller: nil, # Include caller field (nil) to avoid KeyError
          result_handle: <<1::256>>,
          input_handles: %{}
        }
      ]

      timestamp = DateTime.utc_now()
      options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

      # Multi.run unwraps the {:ok, value} tuple
      assert {:ok, %{insert_fhe_operations: [updated]}} =
               Multi.new()
               |> FheOperations.run(changes_list, options)
               |> Repo.transaction()

      # Should replace the existing operation
      assert updated.operation == "FheMul"
      assert updated.hcu_cost == 200

      # Verify only one operation exists
      operations = FheOperation.by_transaction_hash(transaction.hash)
      assert length(operations) == 1
    end

    test "orders operations by transaction_hash and log_index" do
      transaction = insert(:transaction) |> with_block()
      block = transaction.block

      changes_list = [
        %{
          transaction_hash: transaction.hash,
          log_index: 3,
          block_hash: block.hash,
          block_number: block.number,
          operation: "FheAdd",
          operation_type: "arithmetic",
          fhe_type: "Uint8",
          is_scalar: false,
          hcu_cost: 100,
          hcu_depth: 1,
          caller: nil,
          result_handle: <<3::256>>,
          input_handles: %{}
        },
        %{
          transaction_hash: transaction.hash,
          log_index: 1,
          block_hash: block.hash,
          block_number: block.number,
          operation: "FheSub",
          operation_type: "arithmetic",
          fhe_type: "Uint8",
          is_scalar: false,
          hcu_cost: 100,
          hcu_depth: 1,
          caller: nil,
          result_handle: <<1::256>>,
          input_handles: %{}
        },
        %{
          transaction_hash: transaction.hash,
          log_index: 2,
          block_hash: block.hash,
          block_number: block.number,
          operation: "FheMul",
          operation_type: "arithmetic",
          fhe_type: "Uint8",
          is_scalar: false,
          hcu_cost: 100,
          hcu_depth: 1,
          caller: nil,
          result_handle: <<2::256>>,
          input_handles: %{}
        }
      ]

      timestamp = DateTime.utc_now()
      options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

      # Multi.run unwraps the {:ok, value} tuple
      assert {:ok, %{insert_fhe_operations: inserted}} =
               Multi.new()
               |> FheOperations.run(changes_list, options)
               |> Repo.transaction()

      # Verify ordering
      assert length(inserted) == 3
      assert Enum.at(inserted, 0).log_index == 1
      assert Enum.at(inserted, 1).log_index == 2
      assert Enum.at(inserted, 2).log_index == 3
    end

    test "tags contracts from FHE operations" do
      transaction = insert(:transaction) |> with_block()
      block = transaction.block
      caller = insert(:address, contract_code: "0x6080604052")
      to_address = insert(:address, contract_code: "0x6080604052")

      # Set transaction to_address
      transaction
      |> Transaction.changeset(%{to_address_hash: to_address.hash})
      |> Repo.update!()

      changes_list = [
        %{
          transaction_hash: transaction.hash,
          log_index: 1,
          block_hash: block.hash,
          block_number: block.number,
          operation: "FheAdd",
          operation_type: "arithmetic",
          fhe_type: "Uint8",
          is_scalar: false,
          hcu_cost: 100,
          hcu_depth: 1,
          caller: caller.hash,
          result_handle: <<1::256>>,
          input_handles: %{}
        }
      ]

      timestamp = DateTime.utc_now()
      options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

      # Mock RPC calls for FHE checks
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, 2, fn _request, _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
      end)

      assert {:ok, _} =
               Multi.new()
               |> FheOperations.run(changes_list, options)
               |> Repo.transaction()

      # Note: The actual tagging happens asynchronously, so we can't easily test it here
      # without mocking the FheContractChecker module
    end
  end
end

