defmodule Indexer.ReplacedTransaction.FetcherTest do
  use Explorer.DataCase

  alias Explorer.Chain.Transaction
  alias Indexer.ReplacedTransaction

  @moduletag :capture_log

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    :ok
  end

  describe "start_link/1" do
    test "starts finding replaced transactions" do
      common_from_address_hash = %Explorer.Chain.Hash{
        byte_count: 20,
        bytes: <<0x4615CC10092B514258577DAFCA98C142577F1578::big-integer-size(20)-unit(8)>>
      }

      address = insert(:address, hash: common_from_address_hash)

      common_nonce = 10

      replaced_transaction_hash = %Explorer.Chain.Hash{
        byte_count: 32,
        bytes: <<0x9FC76417374AA880D4449A1F7F31EC597F00B1F6F3DD2D66F4C9C6C445836D8B::big-integer-size(32)-unit(8)>>
      }

      insert(:transaction,
        hash: replaced_transaction_hash,
        nonce: common_nonce,
        from_address: address
      )

      mined_transaction_hash = %Explorer.Chain.Hash{
        byte_count: 32,
        bytes: <<0x8FC76417374AA880D4449A1F7F31EC597F00B1F6F3DD2D66F4C9C6C445836D8B::big-integer-size(32)-unit(8)>>
      }

      block = insert(:block)
      insert(:transaction,
        hash: mined_transaction_hash,
        nonce: common_nonce,
        from_address: address,
        block_number: block.number,
        block_hash: block.hash,
        cumulative_gas_used: 10,
        gas_used: 1,
        index: 0,
        status: :ok
      )

      ReplacedTransaction.Supervisor.Case.start_supervised!()

      found_replaced_transaction =
        wait_for_results(fn ->
          Repo.one!(
            from(transaction in Transaction,
              where: transaction.status == ^:error and transaction.error == "dropped/replaced"
            )
          )
        end)

      assert found_replaced_transaction.hash == replaced_transaction_hash
    end
  end
end
