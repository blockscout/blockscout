defmodule Indexer.Fetcher.ReplacedTransactionTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Transaction}
  alias Indexer.Fetcher.ReplacedTransaction

  @moduletag :capture_log

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    :ok
  end

  describe "async_fetch/1" do
    test "updates replaced transaction" do
      replaced_transaction_hash = "0x2a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61"

      address = insert(:address, hash: "0xb7cffe2ac19b9d5705a24cbe14fef5663af905a6")

      insert(:transaction,
        from_address: address,
        nonce: 1,
        block_hash: nil,
        index: nil,
        block_number: nil,
        hash: replaced_transaction_hash
      )

      mined_transaction_hash = "0x1a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61"
      block = insert(:block)

      mined_transaction =
        insert(:transaction,
          from_address: address,
          nonce: 1,
          index: 0,
          block_hash: block.hash,
          block_number: block.number,
          cumulative_gas_used: 1,
          gas_used: 1,
          hash: mined_transaction_hash
        )

      second_mined_transaction_hash = "0x3a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61"
      second_block = insert(:block)

      insert(:transaction,
        from_address: address,
        nonce: 1,
        index: 0,
        block_hash: second_block.hash,
        block_number: second_block.number,
        cumulative_gas_used: 1,
        gas_used: 1,
        hash: second_mined_transaction_hash
      )

      second_replaced_transaction_hash = "0x7a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61"
      second_address = insert(:address, hash: "0xc7cffe2ac19b9d5705a24cbe14fef5663af905a6")

      insert(:transaction,
        from_address: second_address,
        nonce: 1,
        block_hash: nil,
        index: nil,
        block_number: nil,
        hash: second_replaced_transaction_hash
      )

      ReplacedTransaction.Supervisor.Case.start_supervised!()

      assert :ok =
               ReplacedTransaction.async_fetch(
                 [
                   %{
                     block_hash: mined_transaction.block_hash,
                     nonce: mined_transaction.nonce,
                     from_address_hash: mined_transaction.from_address_hash
                   }
                 ],
                 false
               )

      found_replaced_transaction =
        wait(fn ->
          Repo.one!(from(t in Transaction, where: t.hash == ^replaced_transaction_hash and t.status == ^:error))
        end)

      assert found_replaced_transaction.error == "dropped/replaced"

      assert %Transaction{error: nil, status: nil} =
               Repo.one!(from(t in Transaction, where: t.hash == ^mined_transaction_hash))

      assert %Transaction{error: nil, status: nil} =
               Repo.one!(from(t in Transaction, where: t.hash == ^second_mined_transaction_hash))

      assert %Transaction{error: nil, status: nil} =
               Repo.one!(from(t in Transaction, where: t.hash == ^second_replaced_transaction_hash))
    end

    test "updates a replaced transaction on init" do
      replaced_transaction_hash = "0x2a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61"

      address = insert(:address, hash: "0xb7cffe2ac19b9d5705a24cbe14fef5663af905a6")

      insert(:transaction,
        from_address: address,
        nonce: 1,
        block_hash: nil,
        index: nil,
        block_number: nil,
        hash: replaced_transaction_hash
      )

      mined_transaction_hash = "0x1a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61"
      block = insert(:block)

      mined_transaction =
        insert(:transaction,
          from_address: address,
          nonce: 1,
          index: 0,
          block_hash: block.hash,
          block_number: block.number,
          cumulative_gas_used: 1,
          gas_used: 1,
          hash: mined_transaction_hash
        )

      second_mined_transaction_hash = "0x3a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61"
      second_block = insert(:block)

      insert(:transaction,
        from_address: address,
        nonce: 1,
        index: 0,
        block_hash: second_block.hash,
        block_number: second_block.number,
        cumulative_gas_used: 1,
        gas_used: 1,
        hash: second_mined_transaction_hash
      )

      second_replaced_transaction_hash = "0x7a263224a95275d77bc30a7e131bc64d948777946a790c0915ab293791fbcb61"
      second_address = insert(:address, hash: "0xc7cffe2ac19b9d5705a24cbe14fef5663af905a6")

      insert(:transaction,
        from_address: second_address,
        nonce: 1,
        block_hash: nil,
        index: nil,
        block_number: nil,
        hash: second_replaced_transaction_hash
      )

      insert(:transaction,
        from_address: mined_transaction.from_address,
        nonce: mined_transaction.nonce
      )
      |> with_block(block)

      ReplacedTransaction.Supervisor.Case.start_supervised!()

      #      assert :ok =
      #               ReplacedTransaction.async_fetch([
      #                 %{
      #                   block_hash: mined_transaction.block_hash,
      #                   nonce: mined_transaction.nonce,
      #                   from_address_hash: mined_transaction.from_address_hash
      #                 }
      #               ])

      found_replaced_transaction =
        wait(fn ->
          Repo.one!(from(t in Transaction, where: t.hash == ^replaced_transaction_hash and t.status == ^:error))
        end)

      assert found_replaced_transaction.error == "dropped/replaced"

      assert %Transaction{error: nil, status: nil} =
               Repo.one!(from(t in Transaction, where: t.hash == ^mined_transaction_hash))

      assert %Transaction{error: nil, status: nil} =
               Repo.one!(from(t in Transaction, where: t.hash == ^second_mined_transaction_hash))

      assert %Transaction{error: nil, status: nil} =
               Repo.one!(from(t in Transaction, where: t.hash == ^second_replaced_transaction_hash))
    end
  end

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end
end
